"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.idempotencyMiddleware = idempotencyMiddleware;
const cache_util_1 = require("../utils/cache.util");
/**
 * POS Checkout Idempotency Guard Middleware
 * Prevents double-billing and duplicate invoices caused by cashier double-clicks or unstable retail store WiFi.
 */
function idempotencyMiddleware(ttlSeconds = 120) {
    return async (req, res, next) => {
        // Only apply to POST / PUT mutation requests
        if (req.method !== 'POST' && req.method !== 'PUT') {
            return next();
        }
        const idempotencyKey = (req.headers['idempotency-key'] ||
            req.headers['x-idempotency-key'] ||
            req.body?.idempotency_key ||
            req.body?.client_transaction_id);
        if (!idempotencyKey) {
            return next();
        }
        const outletId = req.user?.outlet_id || req.outlet_id || 'global';
        const cacheKey = `idempotency:${outletId}:${idempotencyKey}`;
        try {
            const cachedResponse = await cache_util_1.cache.get(cacheKey);
            if (cachedResponse) {
                console.log(`🛡️ [IDEMPOTENCY] Replaying duplicate request for key [${idempotencyKey}]`);
                res.setHeader('X-Idempotent-Replay', 'true');
                res.status(cachedResponse.statusCode || 200).json(cachedResponse.data);
                return;
            }
            // Intercept res.json to capture response payload for caching
            const originalJson = res.json.bind(res);
            res.json = function (data) {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    cache_util_1.cache.set(cacheKey, { statusCode: res.statusCode, data }, ttlSeconds).catch(() => { });
                }
                return originalJson(data);
            };
            next();
        }
        catch (err) {
            console.warn(`[IDEMPOTENCY] Cache lookup error: ${err.message}. Proceeding with request.`);
            next();
        }
    };
}
module.exports = { idempotencyMiddleware };
exports.default = idempotencyMiddleware;
