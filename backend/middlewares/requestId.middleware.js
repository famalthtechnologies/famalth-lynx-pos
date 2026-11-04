"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestIdMiddleware = requestIdMiddleware;
const crypto_1 = __importDefault(require("crypto"));
/**
 * Request Correlation ID Middleware
 * Tags every HTTP request with a unique ID for end-to-end tracing across Flutter & Backend logs.
 */
function requestIdMiddleware(req, res, next) {
    const incomingId = req.headers['x-request-id'];
    const requestId = incomingId || `req_${Date.now()}_${crypto_1.default.randomBytes(4).toString('hex')}`;
    req.id = requestId;
    res.setHeader('X-Request-ID', requestId);
    next();
}
module.exports = { requestIdMiddleware };
exports.default = requestIdMiddleware;
