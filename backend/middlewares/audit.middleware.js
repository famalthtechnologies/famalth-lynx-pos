"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logAudit = void 0;
const logAudit = async ({ db, user_id, action, table, record_id, meta = {} }) => {
    if (db && db.models && db.models.audit_logs) {
        await db.models.audit_logs.create({
            user_id,
            action,
            table_name: table,
            record_id,
            meta: JSON.stringify(meta)
        });
    }
};
exports.logAudit = logAudit;
module.exports = {
    logAudit: exports.logAudit
};
