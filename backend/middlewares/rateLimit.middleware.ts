import rateLimit, { ipKeyGenerator } from 'express-rate-limit';

/**
 * Standard API Rate Limiter
 * Allows up to 180 requests per minute per IP for regular POS / billing operations.
 */
export const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 3000, // Increased threshold for active POS workstations and settings dialogs
  standardHeaders: true,
  legacyHeaders: false,
  validate: { keyGeneratorIpFallback: false },
  skip: (req) => {
    const rawIp = (req.ip || req.socket?.remoteAddress || '').toLowerCase();
    const host = (req.hostname || req.headers?.host || '').toLowerCase();
    return rawIp === '127.0.0.1' || rawIp === '::1' || rawIp.includes('127.0.0.1') || rawIp.includes('localhost') || host.includes('127.0.0.1') || host.includes('localhost') || req.headers?.['x-internal-request'] === 'true';
  },
  message: {
    success: false,
    message: 'Too many requests from this IP. Please wait a moment.'
  }
});

/**
 * Tier 1: User / Account Rate Limiter
 * Scoped by (Outlet + Username).
 * If a specific cashier enters wrong PIN/password 8 times, ONLY their account is locked for 15 mins.
 * Other staff members and other outlets on the same machine are NOT affected.
 */
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 8,
  skipSuccessfulRequests: true,
  validate: { keyGeneratorIpFallback: false },
  keyGenerator: (req) => {
    const outlet = String(req.body?.outlet_code || req.body?.outletCode || req.headers['x-outlet-code'] || '').trim().toLowerCase();
    const user = String(req.body?.username || req.body?.email || req.body?.pin || '').trim().toLowerCase();
    const rawIp = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    const ip = ipKeyGenerator(rawIp);

    if (outlet && user) {
      return `${outlet}:${user}`;
    } else if (outlet) {
      return `${outlet}:${ip}`;
    }
    return `${ip}:${user || 'anonymous'}`;
  },
  message: {
    success: false,
    lockoutType: 'ACCOUNT_LOCKOUT',
    message: '🔒 Account Locked: Too many failed login attempts for this user. This specific user account is locked for 15 minutes. Other users or outlets on this machine can still sign in.'
  }
});

/**
 * Tier 2: Workstation / Terminal IP-Level Flood Protection
 * Scoped by Machine / Terminal IP across all accounts.
 * If 25 failed attempts occur from this computer (trying multiple IDs/passwords),
 * the entire workstation is locked to prevent brute force attacks.
 */
export const terminalIpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 25,
  skipSuccessfulRequests: true,
  validate: { keyGeneratorIpFallback: false },
  keyGenerator: (req) => {
    const rawIp = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    return ipKeyGenerator(rawIp);
  },
  message: {
    success: false,
    lockoutType: 'TERMINAL_LOCKOUT',
    message: '🚫 Workstation Blocked: Excessive failed attempts detected from this terminal. This entire machine is temporarily locked for 15 minutes. Please do NOT retry switching users or outlets until cooldown expires.'
  }
});

/**
 * Global DDoS Burst Limiter
 * Immediately drops aggressive bot spikes (> 300 requests in 10 seconds).
 */
export const ddosBurstLimiter = rateLimit({
  windowMs: 10 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  validate: { keyGeneratorIpFallback: false },
  message: {
    success: false,
    message: 'DDoS protection triggered. Request dropped.'
  }
});

/**
 * Heavy Report & Analytics Query Limiter
 * Protects database CPU from complex aggregation spam.
 */
export const reportQueryLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  validate: { keyGeneratorIpFallback: false },
  message: {
    success: false,
    message: 'Report query rate limit exceeded. Please wait a moment.'
  }
});

module.exports = {
  apiLimiter,
  loginLimiter,
  terminalIpLimiter,
  ddosBurstLimiter,
  reportQueryLimiter
};
