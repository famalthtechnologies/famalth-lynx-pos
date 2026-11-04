"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.contextMiddleware = void 0;
const { contextStorage } = require('../utils/context');
const contextMiddleware = (req, res, next) => {
    contextStorage.run(new Map(), () => {
        next();
    });
};
exports.contextMiddleware = contextMiddleware;
module.exports = {
    contextMiddleware: exports.contextMiddleware
};
