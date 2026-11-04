"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.isOnline = isOnline;
const dns_1 = __importDefault(require("dns"));
function isOnline() {
    return new Promise((resolve) => {
        dns_1.default.lookup("google.com", (err) => {
            resolve(!err);
        });
    });
}
exports.default = { isOnline };
