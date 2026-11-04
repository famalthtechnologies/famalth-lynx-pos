"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verify = exports.sign = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = __importDefault(require("crypto"));
const loadConfig = require('./decryptConfig');
/**
 * Enterprise JWT Token Manager
 * Resolves JWT_SECRET from environment variables (Cloud Secrets / .env / config.enc)
 * Generates secure dynamic keys in production if missing.
 */
function resolveJwtSecret() {
    if (process.env.JWT_SECRET && process.env.JWT_SECRET.trim().length >= 16) {
        return process.env.JWT_SECRET.trim();
    }
    try {
        const config = loadConfig();
        if (config && config.JWT_SECRET && config.JWT_SECRET.trim().length >= 16) {
            return config.JWT_SECRET.trim();
        }
    }
    catch (error) {
        // config.enc not found on standalone local server
    }
    if (process.env.NODE_ENV === 'production') {
        console.warn('⚠️ [SECURITY WARNING] No secure JWT_SECRET environment variable provided. Using ephemeral runtime key.');
        return crypto_1.default.randomBytes(32).toString('hex');
    }
    return 'retailsale_secure_dev_jwt_secret_key_2026';
}
const jwtSecret = resolveJwtSecret();
const sign = (payload, options = { expiresIn: '1d' }) => {
    return jsonwebtoken_1.default.sign(payload, jwtSecret, options);
};
exports.sign = sign;
const verify = (token) => {
    return jsonwebtoken_1.default.verify(token, jwtSecret);
};
exports.verify = verify;
module.exports = {
    sign: exports.sign,
    verify: exports.verify
};
exports.default = {
    sign: exports.sign,
    verify: exports.verify
};
