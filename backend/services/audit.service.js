"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.log = void 0;
const log = async ({ req, module, action, table, recordId = null, oldData = null, newData = null, outlet_id = null, user_id = null }) => {
    try {
        if (req?.propertyDb?.models?.audit_logs) {
            await req.propertyDb.models.audit_logs.create({
                outlet_id: outlet_id ?? req.user?.outlet_id ?? req.outlet_id,
                user_id: user_id ?? req.user?.id ?? req.user?.user_id,
                module,
                action,
                table_name: table,
                record_id: recordId,
                old_data: oldData,
                new_data: newData,
                ip_address: req.ip,
                user_agent: req.headers ? req.headers['user-agent'] : null
            });
        }
    }
    catch (err) {
        console.error('Audit log failed:', err.message);
    }
};
exports.log = log;
module.exports = {
    log: exports.log
};
