"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.saveBranding = exports.getBranding = exports.defaultBranding = void 0;
const audit = require('../../services/audit.service');
exports.defaultBranding = {
    company_name: 'Famalth Technologies',
    product_name: 'Famalth Inventory',
    support_email: 'help@famalth.com',
    support_website: 'www.famalth.com',
    support_phone: '+91-00000-00000',
    open_source_notice: 'Famalth Technologies branding is applied across the product. Third-party packages remain available under their respective open-source licenses.',
    powered_by_label: 'Powered by Famalth Technologies',
    theme_key: 'famalth_classic'
};
const getBranding = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const branding = await req.propertyDb.models.app_branding.findOne({
            where: { outlet_id }
        });
        if (!branding) {
            return res.json({
                success: true,
                data: exports.defaultBranding
            });
        }
        return res.json({ success: true, data: branding });
    }
    catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};
exports.getBranding = getBranding;
const saveBranding = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const Model = req.propertyDb.models.app_branding;
        const existing = await Model.findOne({
            where: { outlet_id },
            transaction: t
        });
        const oldData = existing ? existing.toJSON() : null;
        const companyName = String(req.body.company_name || exports.defaultBranding.company_name).trim() || exports.defaultBranding.company_name;
        const payload = {
            outlet_id,
            company_name: companyName,
            product_name: String(req.body.product_name || exports.defaultBranding.product_name).trim() || exports.defaultBranding.product_name,
            support_email: String(req.body.support_email || exports.defaultBranding.support_email).trim() || exports.defaultBranding.support_email,
            support_website: String(req.body.support_website || exports.defaultBranding.support_website).trim() ||
                exports.defaultBranding.support_website,
            support_phone: String(req.body.support_phone || exports.defaultBranding.support_phone).trim() || exports.defaultBranding.support_phone,
            open_source_notice: String(req.body.open_source_notice || exports.defaultBranding.open_source_notice).trim() ||
                exports.defaultBranding.open_source_notice,
            powered_by_label: String(req.body.powered_by_label || '').trim() || `Powered by ${companyName}`,
            theme_key: String(req.body.theme_key || exports.defaultBranding.theme_key).trim() || exports.defaultBranding.theme_key,
            home_bg_image_path: req.body.home_bg_image_path ? String(req.body.home_bg_image_path).trim() : null,
            home_bg_image_size: req.body.home_bg_image_size ? String(req.body.home_bg_image_size).trim() : 'Cover',
            home_theme_style: req.body.home_theme_style ? String(req.body.home_theme_style).trim() : 'Default'
        };
        let record;
        if (existing) {
            record = await existing.update(payload, { transaction: t });
        }
        else {
            record = await Model.create(payload, { transaction: t });
        }
        await audit.log({
            req,
            module: 'APP_BRANDING',
            action: existing ? 'UPDATE' : 'CREATE',
            table: 'app_branding',
            recordId: record.id,
            oldData,
            newData: record.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });
        await t.commit();
        return res.json({
            success: true,
            message: 'Application branding saved successfully',
            data: record
        });
    }
    catch (err) {
        await t.rollback();
        return res.status(500).json({ success: false, error: err.message });
    }
};
exports.saveBranding = saveBranding;
module.exports = {
    getBranding: exports.getBranding,
    saveBranding: exports.saveBranding,
    defaultBranding: exports.defaultBranding
};
