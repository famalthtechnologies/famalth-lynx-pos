"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getNextNumber = void 0;
const numberingHelper = require('../controllers/inventory/numberingSettingsV2.controller');

const getNextNumber = async (db, outlet_id, module, transaction) => {
    try {
        const allocated = await numberingHelper.allocateNextNumber({
            db,
            outlet_id,
            module,
            transaction
        });
        if (allocated && allocated.number) {
            return allocated.number;
        }
    } catch (_) {}

    const queryOptions = {
        where: { outlet_id, module }
    };
    if (transaction) {
        queryOptions.transaction = transaction;
        if (transaction.LOCK && transaction.LOCK.UPDATE) {
            queryOptions.lock = transaction.LOCK.UPDATE;
        }
    }

    const setting = await db.models.numbering_settings.findOne(queryOptions);
    if (!setting)
        throw new Error(`Numbering not configured for module ${module}`);
    const startNo = Math.max(1, Math.round(Number(setting.start_no) || 1));
    const lastUsedNo = Math.round(Number(setting.last_used_no) || 0);
    const nextNo = lastUsedNo === 0 ? startNo : lastUsedNo + 1;
    const finalNo = `${setting.prefix || ''}${nextNo}${setting.postfix || ''}`;
    await setting.update({ last_used_no: nextNo }, { transaction });
    return finalNo;
};
exports.getNextNumber = getNextNumber;
module.exports = {
    getNextNumber: exports.getNextNumber
};
