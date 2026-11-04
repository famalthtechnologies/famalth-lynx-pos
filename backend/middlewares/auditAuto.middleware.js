"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.auditAutoMiddleware = void 0;
const auditAutoMiddleware = (moduleName, tableName) => {
    return async (req, res, next) => {
        res.on('finish', async () => {
            if (![200, 201].includes(res.statusCode))
                return;
            const action = req.method === 'POST'
                ? 'CREATE'
                : req.method === 'PUT'
                    ? 'UPDATE'
                    : req.method === 'DELETE'
                        ? 'DELETE'
                        : 'READ';
            if (req.propertyDb && req.propertyDb.models && req.propertyDb.models.audit_logs) {
                try {
                    await req.propertyDb.models.audit_logs.create({
                        outlet_id: req.outlet_id,
                        user_id: req.user?.user_id,
                        module: moduleName,
                        action,
                        table_name: tableName,
                        ip_address: req.ip,
                        user_agent: req.headers['user-agent']
                    });
                }
                catch (err) {
                    console.warn('[AUDIT_AUTO ERROR]', err.message);
                }
            }
        });
        next();
    };
};
exports.auditAutoMiddleware = auditAutoMiddleware;
module.exports = exports.auditAutoMiddleware;
exports.default = exports.auditAutoMiddleware;
