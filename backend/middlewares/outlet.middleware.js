"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.outletMiddleware = void 0;
const { contextStorage } = require('../utils/context');
const outletMiddleware = async (req, res, next) => {
    const store = contextStorage.getStore();
    let outletId = store?.get('outlet_id') || req.outlet_id || req.user?.outlet_id;
    let outlet;
    if (outletId && req.propertyDb) {
        outlet = await req.propertyDb.models.outlets.findOne({
            where: { id: outletId, is_active: true }
        });
    }
    else if (req.propertyDb) {
        // Fallback for compatibility/legacy: find the first active outlet
        outlet = await req.propertyDb.models.outlets.findOne({
            where: { is_active: true }
        });
    }
    if (!outlet) {
        return res.status(412).json({
            success: false,
            code: 'OUTLET_NOT_CONFIGURED',
            message: 'Outlet not configured'
        });
    }
    req.outlet = outlet;
    if (store && !store.has('outlet_id')) {
        store.set('outlet_id', outlet.id);
    }
    next();
};
exports.outletMiddleware = outletMiddleware;
module.exports = exports.outletMiddleware;
exports.default = exports.outletMiddleware;
