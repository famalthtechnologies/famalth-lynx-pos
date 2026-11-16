const audit = require('../../services/audit.service');
const { Op } = require('sequelize');

function toWholeNumber(value: any, fallback = 1) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(1, Math.round(parsed));
}

function normalizeDate(value: any) {
    if (!value) return new Date();
    if (value instanceof Date) {
        return Number.isNaN(value.getTime()) ? new Date() : value;
    }
    const str = String(value).trim();
    let d = new Date(str);
    if (!Number.isNaN(d.getTime())) return d;

    const dmy = str.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
    if (dmy) {
        d = new Date(`${dmy[3]}-${dmy[2].padStart(2, '0')}-${dmy[1].padStart(2, '0')}`);
        if (!Number.isNaN(d.getTime())) return d;
    }

    const dMonY = str.match(/^(\d{1,2})[\/\-]([A-Za-z]{3})[\/\-](\d{4})/);
    if (dMonY) {
        d = new Date(`${dMonY[1]} ${dMonY[2]} ${dMonY[3]}`);
        if (!Number.isNaN(d.getTime())) return d;
    }

    return new Date();
}

function extractNumericPart(value: any, setting: any) {
    const raw = String(value || '').trim();
    if (!raw) return null;
    const prefix = String(setting.prefix || '').trim();
    const postfix = String(setting.postfix || '').trim();
    let middle = raw;

    if (prefix) {
        if (middle.toLowerCase().startsWith(prefix.toLowerCase())) {
            middle = middle.substring(prefix.length);
        } else {
            return null;
        }
    }
    if (postfix) {
        if (middle.toLowerCase().endsWith(postfix.toLowerCase())) {
            middle = middle.substring(0, middle.length - postfix.length);
        } else {
            const fyMatch = middle.match(/^(.*?)(-\d{2}\/\d{2}|-\d{4}\/\d{2}|-\d{2}-\d{2}|-\d{2})$/);
            if (fyMatch && /^\d+$/.test(fyMatch[1])) {
                middle = fyMatch[1];
            } else {
                return null;
            }
        }
    }

    // Must be pure digits
    if (!/^\d+$/.test(middle)) {
        return null;
    }

    const parsed = parseInt(middle, 10);
    if (Number.isNaN(parsed)) return null;

    // Reject date-formatted or timestamp-derived pseudo sequence numbers (e.g. 20261005) if standard sequence starts small
    const startNo = Number(setting.start_no) || 1;
    if (parsed > 1000000 && startNo < 100000) {
        return null;
    }

    return parsed;
}

async function getEffectiveSetting({ db, outlet_id, module, date, transaction }: { db: any; outlet_id: any; module: any; date: any; transaction?: any }) {
    const docDate = normalizeDate(date);

    const queryOptions: any = {
        where: { outlet_id: Number(outlet_id), module: String(module).trim().toUpperCase() },
        order: [['start_date', 'DESC']]
    };
    if (transaction) {
        queryOptions.transaction = transaction;
        if (transaction.LOCK && transaction.LOCK.UPDATE) {
            queryOptions.lock = transaction.LOCK.UPDATE;
        }
    }

    const settings = await db.models.numbering_settings.findAll(queryOptions);

    if (!settings || settings.length === 0) {
        return null;
    }

    const docDateStr = docDate.toISOString().substring(0, 10);

    const effective = settings.find((setting: any) => {
        const startDateStr = String(setting.start_date || '').substring(0, 10);
        return docDateStr >= startDateStr;
    }) || settings[0];

    if (!effective) {
        return null;
    }

    const nextSetting = settings
        .filter((setting: any) => String(setting.start_date || '').substring(0, 10) > String(effective.start_date || '').substring(0, 10))
        .sort((a: any, b: any) => new Date(a.start_date).getTime() - new Date(b.start_date).getTime())[0] || null;

    return { effective, nextSetting };
}

async function getExistingNumbersForModule({
    db,
    req,
    module,
    outlet_id,
    startDate,
    endDate,
    transaction
}: {
    db?: any;
    req?: any;
    module: any;
    outlet_id: any;
    startDate?: any;
    endDate?: any;
    transaction?: any;
}) {
    const database = db || req?.propertyDb || req?.db;
    if (!database || !database.models) return [];

    let Model;
    let numberField: string;
    let dateField: string = 'created_at';
    const mod = String(module).trim().toUpperCase();

    switch (mod) {
        case 'PO':
            Model = database.models.purchase_orders;
            numberField = 'po_no';
            dateField = 'po_date';
            break;
        case 'KOT':
            Model = database.models.kot_headers;
            numberField = 'kot_no';
            dateField = 'created_at';
            break;
        case 'RECEIVING':
            Model = database.models.goods_receipts;
            numberField = 'grn_no';
            dateField = 'receipt_date';
            break;
        case 'INDENT':
            Model = database.models.issue_headers;
            numberField = 'issue_no';
            dateField = 'issue_date';
            break;
        case 'REQUEST':
            Model = database.models.request_headers;
            numberField = 'request_no';
            dateField = 'request_date';
            break;
        case 'DAMAGE':
            Model = database.models.damage_headers;
            numberField = 'damage_no';
            dateField = 'damage_date';
            break;
        case 'SALES':
            Model = database.models.sales_headers;
            numberField = 'sale_no';
            dateField = 'sale_date';
            break;
        case 'TOKEN':
            Model = database.models.sales_headers;
            numberField = 'token_no';
            dateField = 'sale_date';
            break;
        case 'CONTRA':
        case 'PAYMENT':
        case 'RECEIPT':
        case 'JOURNAL':
            Model = database.models.accounting_vouchers;
            numberField = 'voucher_no';
            dateField = 'voucher_date';
            break;
        default:
            throw new Error(`Unsupported module ${module}`);
    }

    if (!Model) return [];

    const where: any = {
        outlet_id: Number(outlet_id)
    };

    if (mod === 'SALES') {
        where.is_latest = true;
        where.is_deleted = false;
    }

    if (['CONTRA', 'PAYMENT', 'RECEIPT', 'JOURNAL'].includes(mod)) {
        where.voucher_type = mod;
    }

    if (startDate) {
        const startStr = String(startDate).substring(0, 10);
        const startDay = new Date(`${startStr}T00:00:00`);
        if (!Number.isNaN(startDay.getTime())) {
            const dateFilter: any = { [Op.gte]: startDay };
            if (endDate) {
                const endStr = String(endDate).substring(0, 10);
                const endDay = new Date(`${endStr}T00:00:00`);
                if (!Number.isNaN(endDay.getTime())) {
                    dateFilter[Op.lt] = endDay;
                }
            }
            if (dateField && dateField !== 'created_at') {
                where[Op.or] = [
                    { [dateField]: dateFilter },
                    { created_at: dateFilter }
                ];
            } else {
                where.created_at = dateFilter;
            }
        }
    }

    const queryOptions: any = {
        where,
        attributes: [numberField],
        order: [['id', 'DESC']],
        limit: 100
    };
    if (transaction) {
        queryOptions.transaction = transaction;
    }

    const rows = await Model.findAll(queryOptions);

    return rows.map((row: any) => row[numberField]).filter(Boolean);
}

async function allocateNextNumber({
    db,
    req,
    outlet_id,
    module,
    date,
    transaction
}: {
    db?: any;
    req?: any;
    outlet_id: any;
    module: any;
    date?: any;
    transaction?: any;
}) {
    const database = db || req?.propertyDb || req?.db;
    const mod = String(module).trim().toUpperCase();
    const resolved = await getEffectiveSetting({
        db: database,
        outlet_id,
        module: mod,
        date,
        transaction
    });

    if (resolved && resolved.effective) {
        const { effective, nextSetting } = resolved;
        const existingNumbers = await getExistingNumbersForModule({
            db: database,
            module: mod,
            outlet_id,
            startDate: effective.start_date,
            endDate: nextSetting ? nextSetting.start_date : null,
            transaction
        });

        // Always base sequence strictly on the ACTUAL MAXIMUM number committed in the database table
        let maxSavedNo = toWholeNumber(effective.start_no) - 1;
        for (const value of existingNumbers) {
            const numeric = extractNumericPart(value, effective);
            if (numeric !== null && numeric > maxSavedNo) {
                maxSavedNo = numeric;
            }
        }
        const nextNo = maxSavedNo + 1;

        try {
            await effective.update({ last_used_no: nextNo }, { transaction });
        } catch (_) {}

        return {
            number: `${effective.prefix || ''}${nextNo}${effective.postfix || ''}`,
            next_no: nextNo
        };
    }

    // Default sequence fallbacks if no numbering setting exists
    const existingNumbers = await getExistingNumbersForModule({
        db: database,
        module: mod,
        outlet_id,
        transaction
    });

    let prefix = `${mod}-`;
    if (mod === 'SALES') prefix = 'FAM-';
    else if (mod === 'TOKEN') prefix = 'TK-';
    else if (mod === 'KOT') prefix = 'KOT-';
    else if (mod === 'RECEIVING') prefix = 'RC-';
    else if (mod === 'PO') prefix = 'PO-';
    else if (mod === 'INDENT') prefix = 'INT-';
    else if (mod === 'REQUEST') prefix = 'REC-';
    else if (mod === 'DAMAGE') prefix = 'DMG-';
    else if (mod === 'CONTRA') prefix = 'CNT-';
    else if (mod === 'PAYMENT') prefix = 'PAY-';
    else if (mod === 'RECEIPT') prefix = 'RCT-';
    else if (mod === 'JOURNAL') prefix = 'JRN-';

    let maxNum = 0;
    for (const val of existingNumbers) {
        const str = String(val || '').trim();
        const m = str.match(/(\d+)$/);
        if (m) {
            const n = parseInt(m[1], 10);
            if (!Number.isNaN(n) && n > maxNum && n < 10000000) {
                maxNum = n;
            }
        }
    }
    const nextNo = maxNum > 0 ? maxNum + 1 : 1001;
    return {
        number: `${prefix}${nextNo}`,
        next_no: nextNo
    };
}

// PEEK ONLY: purely read-only preview for UI display without reserving or modifying the database
async function resolveNextNumber({ req, db, module, date, outlet_id }: { req?: any; db?: any; module: any; date: any; outlet_id: any; transaction?: any }) {
    const database = db || req?.propertyDb || req?.db;
    const mod = String(module).trim().toUpperCase();
    const resolved = await getEffectiveSetting({
        db: database,
        outlet_id,
        module: mod,
        date
    });

    if (resolved && resolved.effective) {
        const { effective, nextSetting } = resolved;
        const existingNumbers = await getExistingNumbersForModule({
            db: database,
            module: mod,
            outlet_id,
            startDate: effective.start_date,
            endDate: nextSetting ? nextSetting.start_date : null
        });

        let maxSavedNo = toWholeNumber(effective.start_no) - 1;
        for (const value of existingNumbers) {
            const numeric = extractNumericPart(value, effective);
            if (numeric !== null && numeric > maxSavedNo) {
                maxSavedNo = numeric;
            }
        }
        const nextNo = maxSavedNo + 1;

        return {
            number: `${effective.prefix || ''}${nextNo}${effective.postfix || ''}`,
            next_no: nextNo
        };
    }

    // Fallback peek
    const existingNumbers = await getExistingNumbersForModule({
        db: database,
        module: mod,
        outlet_id
    });

    let prefix = `${mod}-`;
    if (mod === 'SALES') prefix = 'FAM-';
    else if (mod === 'TOKEN') prefix = 'TK-';
    else if (mod === 'KOT') prefix = 'KOT-';
    else if (mod === 'RECEIVING') prefix = 'RC-';
    else if (mod === 'PO') prefix = 'PO-';
    else if (mod === 'INDENT') prefix = 'INT-';
    else if (mod === 'REQUEST') prefix = 'REC-';
    else if (mod === 'DAMAGE') prefix = 'DMG-';
    else if (mod === 'CONTRA') prefix = 'CNT-';
    else if (mod === 'PAYMENT') prefix = 'PAY-';
    else if (mod === 'RECEIPT') prefix = 'RCT-';
    else if (mod === 'JOURNAL') prefix = 'JRN-';

    let maxNum = 0;
    for (const val of existingNumbers) {
        const str = String(val || '').trim();
        const m = str.match(/(\d+)$/);
        if (m) {
            const n = parseInt(m[1], 10);
            if (!Number.isNaN(n) && n > maxNum && n < 10000000) {
                maxNum = n;
            }
        }
    }
    const nextNo = maxNum > 0 ? maxNum + 1 : 1001;
    return {
        number: `${prefix}${nextNo}`,
        next_no: nextNo
    };
}

exports.getSettings = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const settings = await req.propertyDb.models.numbering_settings.findAll({
            where: { outlet_id },
            order: [['module', 'ASC'], ['start_date', 'DESC']]
        });

        res.json({ success: true, data: settings });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveSettings = async (req: any, res: any) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const settings = Array.isArray(req.body) ? req.body : [];
        const Model = req.propertyDb.models.numbering_settings;

        // Enforce mandatory prefix/postfix and global prefix uniqueness.
        const seenIncoming = new Set<string>();
        for (const row of settings) {
            const prefixRaw = String(row?.prefix || '').trim();
            const postfixRaw = String(row?.postfix || '').trim();
            const moduleCode = String(row?.module || '').trim().toUpperCase();

            if (!prefixRaw) {
                throw new Error(`Prefix is required for module ${moduleCode || 'UNKNOWN'}`);
            }
            if (!postfixRaw) {
                throw new Error(`Postfix is required for module ${moduleCode || 'UNKNOWN'}`);
            }

            const normalized = prefixRaw.toUpperCase();
            if (seenIncoming.has(normalized)) {
                throw new Error(`Prefix already used. Try different prefix: ${prefixRaw}`);
            }
            seenIncoming.add(normalized);
        }

        for (const row of settings) {
            const prefixRaw = String(row?.prefix || '').trim();

            const conflictWhere: any = {
                outlet_id: outlet_id,
                [Op.and]: [
                    req.propertyDb.where(
                        req.propertyDb.fn('UPPER', req.propertyDb.fn('TRIM', req.propertyDb.col('prefix'))),
                        prefixRaw.toUpperCase()
                    )
                ]
            };
            if (row.id) {
                conflictWhere.id = { [Op.ne]: Number(row.id) || 0 };
            }

            const conflict = await Model.findOne({
                where: conflictWhere,
                transaction: t
            });
            if (conflict) {
                throw new Error(`Prefix already used. Try different prefix: ${prefixRaw}`);
            }
        }

        for (const s of settings) {
            const existing = s.id
                ? await Model.findOne({
                    where: { id: s.id, outlet_id },
                    transaction: t
                })
                : await Model.findOne({
                    where: { outlet_id, module: s.module, start_date: s.start_date },
                    transaction: t
                });

            const oldData = existing ? existing.toJSON() : null;
            const payload = {
                outlet_id,
                module: s.module,
                start_date: s.start_date,
                start_no: toWholeNumber(s.start_no),
                prefix: String(s.prefix || '').trim(),
                postfix: String(s.postfix || '').trim()
            };

            let record;
            if (existing) {
                record = await existing.update(payload, { transaction: t });
            } else {
                record = await Model.create(payload, { transaction: t });
            }

            await audit.log({
                req,
                module: 'NUMBERING_SETTINGS',
                action: existing ? 'UPDATE' : 'CREATE',
                table: 'numbering_settings',
                recordId: record.id,
                oldData,
                newData: record.toJSON(),
                outlet_id: req.user.outlet_id,
                user_id: req.user.id
            });
        }

        await t.commit();
        res.json({ success: true, message: 'Numbering settings saved' });
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getNextNumber = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { module, date } = req.query;
        const data = await resolveNextNumber({
            req,
            module,
            date,
            outlet_id
        });
        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'Numbering not set for this date'
            });
        }

        res.json({
            success: true,
            data
        });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getEffectiveSetting = getEffectiveSetting;
exports.extractNumericPart = extractNumericPart;
exports.resolveNextNumber = resolveNextNumber;
exports.allocateNextNumber = allocateNextNumber;


module.exports = exports;
export default exports;
