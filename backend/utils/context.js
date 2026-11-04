"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.contextStorage = void 0;
const async_hooks_1 = require("async_hooks");
exports.contextStorage = new async_hooks_1.AsyncLocalStorage();
module.exports = {
    contextStorage: exports.contextStorage
};
