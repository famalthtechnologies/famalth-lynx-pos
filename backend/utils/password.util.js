"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashPassword = hashPassword;
exports.comparePassword = comparePassword;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
/**
 * Enterprise Password & PIN Hashing Utility
 * Standardizes Bcrypt salt cost (12 rounds) across all user creations and PIN updates.
 */
const SALT_ROUNDS = 12;
async function hashPassword(plainText) {
    if (!plainText) {
        throw new Error('Cannot hash empty password or PIN.');
    }
    return bcryptjs_1.default.hash(plainText, SALT_ROUNDS);
}
async function comparePassword(plainText, hashed) {
    if (!plainText || !hashed) {
        return false;
    }
    return bcryptjs_1.default.compare(plainText, hashed);
}
module.exports = {
    SALT_ROUNDS,
    hashPassword,
    comparePassword
};
exports.default = {
    SALT_ROUNDS,
    hashPassword,
    comparePassword
};
