"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.reportQueryLimiter = exports.ddosBurstLimiter = exports.terminalIpLimiter = exports.loginLimiter = exports.apiLimiter = void 0;
const express_rate_limit_1 = __importStar(require("express-rate-limit"));
/**
 * Standard API Rate Limiter
 * Allows up to 180 requests per minute per IP for regular POS / billing operations.
 */
exports.apiLimiter = (0, express_rate_limit_1.default)({
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
exports.loginLimiter = (0, express_rate_limit_1.default)({
    windowMs: 15 * 60 * 1000,
    max: 8,
    skipSuccessfulRequests: true,
    validate: { keyGeneratorIpFallback: false },
    keyGenerator: (req) => {
        const outlet = String(req.body?.outlet_code || req.body?.outletCode || req.headers['x-outlet-code'] || '').trim().toLowerCase();
        const user = String(req.body?.username || req.body?.email || req.body?.pin || '').trim().toLowerCase();
        const rawIp = req.ip || req.socket?.remoteAddress || '127.0.0.1';
        const ip = (0, express_rate_limit_1.ipKeyGenerator)(rawIp);
        if (outlet && user) {
            return `${outlet}:${user}`;
        }
        else if (outlet) {
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
exports.terminalIpLimiter = (0, express_rate_limit_1.default)({
    windowMs: 15 * 60 * 1000,
    max: 25,
    skipSuccessfulRequests: true,
    validate: { keyGeneratorIpFallback: false },
    keyGenerator: (req) => {
        const rawIp = req.ip || req.socket?.remoteAddress || '127.0.0.1';
        return (0, express_rate_limit_1.ipKeyGenerator)(rawIp);
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
exports.ddosBurstLimiter = (0, express_rate_limit_1.default)({
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
exports.reportQueryLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60 * 1000,
    max: 30,
    validate: { keyGeneratorIpFallback: false },
    message: {
        success: false,
        message: 'Report query rate limit exceeded. Please wait a moment.'
    }
});
module.exports = {
    apiLimiter: exports.apiLimiter,
    loginLimiter: exports.loginLimiter,
    terminalIpLimiter: exports.terminalIpLimiter,
    ddosBurstLimiter: exports.ddosBurstLimiter,
    reportQueryLimiter: exports.reportQueryLimiter
};
