"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.propertyContextMiddleware = void 0;
const propertyDb = require('../db/models/index');
const propertyContextMiddleware = async (req, res, next) => {
    if (req.user) {
        req.outlet_id = req.user.outlet_id;
    }
    req.propertyDb = propertyDb;
    next();
};
exports.propertyContextMiddleware = propertyContextMiddleware;
module.exports = exports.propertyContextMiddleware;
exports.default = exports.propertyContextMiddleware;
