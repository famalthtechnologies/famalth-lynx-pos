"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cache = exports.isRedisEnabled = void 0;
const cache_util_1 = require("../utils/cache.util");
Object.defineProperty(exports, "cache", { enumerable: true, get: function () { return cache_util_1.cache; } });
/**
 * Resilient Cache & Redis Connector
 * If Redis environment variables are defined, provides Redis access;
 * otherwise provides automatic in-memory caching fallback for local servers.
 */
const isRedisEnabled = () => {
    return Boolean(process.env.REDIS_URL || process.env.REDIS_HOST);
};
exports.isRedisEnabled = isRedisEnabled;
exports.default = cache_util_1.cache;
