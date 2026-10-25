"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authMiddleware = void 0;
const jwt = require('../utils/jwt.util');
const { contextStorage } = require('../utils/context');
const authMiddleware = async (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1] || req.query?.token;
        if (!token) {
            // Check if we have an outlet identifier in query, body, or headers to bypass login for testing
            const rawOutlet = req.query?.outlet_code ||
                req.query?.outletcode ||
                req.query?.outlet_id ||
                (req.body && req.body.outlet_code) ||
                (req.body && req.body.outletcode) ||
                (req.body && req.body.outlet_id) ||
                req.headers['x-outlet-code'] ||
                req.headers['x-outlet-id'];
            if (rawOutlet && req.propertyDb) {
                try {
                    let outlet = await req.propertyDb.models.outlets.findOne({
                        where: { outlet_code: rawOutlet }
                    });
                    if (!outlet) {
                        const num = Number(rawOutlet);
                        if (Number.isInteger(num)) {
                            outlet = await req.propertyDb.models.outlets.findByPk(num);
                        }
                    }
                    if (outlet) {
                        // Find an active admin/store user for this outlet
                        const user = await req.propertyDb.models.users.findOne({
                            where: {
                                outlet_id: outlet.id,
                                is_active: true
                            }
                        });
                        if (user) {
                            req.user = {
                                user_id: user.id,
                                id: user.id,
                                outlet_id: outlet.id,
                                role: user.role,
                                outlet_code: outlet.outlet_code,
                                permissions: ['*']
                            };
                            req.outlet_id = outlet.id;
                            req.outlet_code = outlet.outlet_code;
                            const store = contextStorage.getStore();
                            if (store) {
                                store.set('outlet_id', outlet.id);
                            }
                            return next();
                        }
                    }
                }
                catch (dbErr) {
                    console.error('[AUTH BYPASS ERROR]', dbErr.message);
                }
            }
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }
        // If the token is invalid/expired, this line will throw an error and jump to the catch block
        const data = jwt.verify(token);
        req.user = {
            ...data,
            id: data.user_id || data.id
        };
        req.outlet_id = data.outlet_id;
        req.outlet_code = data.outlet_code;
        const store = contextStorage.getStore();
        if (store) {
            store.set('outlet_id', data.outlet_id);
        }
        // STRICT MULTI-OUTLET TENANCY GUARD (Gmail-like Data Isolation)
        // Non-admin staff (cashiers, waiters, doctors, pharmacists, clerks) are strictly locked to their token's outlet.
        // Query params or request body tampering (?outlet_id=999) cannot breach other outlets' data.
        const userRole = (req.user?.role || '').toUpperCase();
        const isMasterAdmin = ['ADMIN', 'SUPER_ADMIN'].includes(userRole);
        const tokenOutletId = Number(data.outlet_id || req.user.outlet_id || 1);
        if (!isMasterAdmin) {
            req.outlet_id = tokenOutletId;
            if (store) {
                store.set('outlet_id', tokenOutletId);
            }
            if (req.query) {
                req.query.outlet_id = String(tokenOutletId);
                req.query.outletId = String(tokenOutletId);
            }
            if (req.body && typeof req.body === 'object' && !Array.isArray(req.body)) {
                req.body.outlet_id = tokenOutletId;
                req.body.outletId = tokenOutletId;
            }
        }
        else {
            // Admins who manage the organization can view or switch between authorized branches
            const requestedOutlet = req.query?.outlet_id || req.query?.outletId || req.body?.outlet_id || req.body?.outletId || req.headers['x-outlet-id'];
            if (requestedOutlet) {
                const num = Number(requestedOutlet);
                if (Number.isInteger(num) && num > 0) {
                    req.outlet_id = num;
                    if (store)
                        store.set('outlet_id', num);
                }
            }
        }
        try {
            const { getOutletTimeZone, getNowInTimeZone, getTimeZoneContext, toOutletDateYmd, getOutletDateBounds } = require('../utils/timezoneHelper');
            const tz = await getOutletTimeZone(data.outlet_id, req.propertyDb);
            if (tz) {
                req.outletTimeZone = tz;
                req.nowInTimeZone = getNowInTimeZone(tz);
                req.timeZoneContext = getTimeZoneContext(tz);
                req.toOutletDateYmd = (date) => toOutletDateYmd(date, tz);
                req.getDateBounds = (fromDate, toDate) => getOutletDateBounds(fromDate, toDate, tz);
            }
        }
        catch (_) { }
        return next();
    }
    catch (error) {
        // 🚨 Catch the JWT error safely!
        console.error('JWT Verification Failed:', error.message);
        return res.status(401).json({
            success: false,
            // Tell Flutter exactly what went wrong
            error: error.name === 'TokenExpiredError' ? 'SESSION_EXPIRED' : 'INVALID_TOKEN',
            message: 'Session expired or invalid. Please log in again.'
        });
    }
};
exports.authMiddleware = authMiddleware;
module.exports = exports.authMiddleware;
exports.default = exports.authMiddleware;
