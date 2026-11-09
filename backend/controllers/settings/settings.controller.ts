const { QueryTypes } = require("sequelize");
const audit = require('../../services/audit.service');
const DataRetentionService = require('../../services/dataRetention.service').default || require('../../services/dataRetention.service');
const { resolveBusinessModule } = require('../../utils/moduleHelper');

const TRANSACTION_TABLES = [
    // KOT & Restaurant transactional tables (dependent children first)
    'kot_revisions',
    'kot_items',
    'kot_headers',
    'restaurant_audit_trail',
    'table_reservations',

    // Lucky Draw Campaign tables (dependent children first)
    'draw_vouchers',
    'customer_draw_progress',
    'lucky_draw_campaigns',

    // WhatsApp tables (dependent children first)
    'whatsapp_logs',
    'whatsapp_campaigns',

    // 1. Supplier Return tables (dependent children first)
    'supplier_return_refunds',
    'supplier_return_items',
    'supplier_return_headers',

    // 2. Goods Receipt tables (dependent children first)
    'goods_receipt_items',
    'goods_receipts',

    // 3. Supplier Payments & Bills
    'supplier_payments',
    'supplier_bills',

    // 4. Purchase Orders
    'purchase_order_items',
    'purchase_orders',

    // 5. Return Headers & Items (reference issue_headers)
    'return_items',
    'return_headers',

    // 6. Issue Headers & Items
    'issue_items',
    'issue_headers',

    // 7. Damage Headers & Items
    'damage_items',
    'damage_headers',

    // 8. Assembly Headers & Items
    'assembly_items',
    'assembly_headers',

    // 9. Request Headers & Items
    'request_items',
    'request_headers',

    // Milk Subscription tables
    'milk_subscription_consumptions',
    'milk_subscription_items',
    'milk_subscription_settlements',
    'milk_subscription_schemes',
    'milk_subscriptions',

    // HRMS tables (dependent children first)
    'hr_loan_transactions',
    'hr_loans',
    'hr_sales_commissions',
    'hr_cashier_handovers',
    'hr_payroll_details',
    'hr_payroll_runs',
    'hr_salary_revisions',
    'hr_arrears',
    'hr_attendance_punches',
    'hr_leave_balances',
    'hr_leave_applications',
    'hr_employees',
    'hr_pay_structure_components',
    'hr_pay_structures',
    'hr_salary_components',
    'hr_leave_types',
    'hr_shifts',
    'hr_designations',
    'hr_holidays',

    // 11. Sales & Customer Advances tables
    'sales_items',
    'customer_repayments',
    'customer_advances',
    'customer_item_advances',
    'sales_refunds',
    'sales_credit_notes',
    'customer_orders',
    'sales_headers',

    // 12. Miscellaneous/Independent tables
    'sales_scheme_customers',
    'customer_loyalty_ledger',
    'loyalty_master_config',
    'cash_ledger',
    'expense_entries',
    'expenses',
    'expense_taxes',
    'expense_deductions',
    'expense_categories',
    'taxes_master',
    'daily_opening_balances',
    'stock_ledger',
    'system_notifications',
    'audit_logs',
    'commission_rules'
];

const PROTECTED_TABLES = new Set([
    'schema_version',
]);

const WIPE_TABLES = [...new Set(TRANSACTION_TABLES)].filter(
    (tableName) => !PROTECTED_TABLES.has(tableName)
);
exports.getSettings = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        let settings = null;
        try {
            settings = await req.propertyDb.models.system_settings.findOne({
                where: { outlet_id }
            });
        } catch (dbErr) {
            console.warn("⚠️ System settings query failed in getSettings, trying fallback without merchant_upi_id:", dbErr.message);
            try {
                const attributes = Object.keys(req.propertyDb.models.system_settings.rawAttributes).filter(
                    attr => attr !== 'merchant_upi_id'
                );
                settings = await req.propertyDb.models.system_settings.findOne({
                    where: { outlet_id },
                    attributes: attributes
                });
            } catch (fallbackErr) {
                console.error("❌ Fallback query in getSettings failed:", fallbackErr.stack);
            }
        }

        const outlet = await req.propertyDb.models.outlets.findByPk(outlet_id).catch(() => null);
        const hasInv = (typeof require('../../utils/moduleHelper').hasInventory === 'function' ? require('../../utils/moduleHelper').hasInventory(outlet?.business_module) : false);
        // first time → defaults
        if (!settings) {
            return res.json({
                success: true,
                data: {
                    auto_reorder: true,
                    allow_negative_stock: !hasInv,
                    damage_approval_required: true,
                    enable_audit_log: true,
                    auto_print_on_save: false,
                    enable_item_images_in_sales: false,
                    print_mode: 'PRINT_DIALOG',
                    default_printer_name: '',
                    default_printer_url: '',
                    billing_country: 'India',
                    time_zone: 'Asia/Kolkata',
                    billing_tax_mode: 'CGST_SGST',
                    bill_format: 'A4',
                    default_charges: [],
                    voucher_rules: [],
                    is_cloud_enabled: false,
                    enable_app_subscription: false,
                    enable_payment_gateway: false,
                    payment_gateway_provider: 'SANDBOX',
                    payment_gateway_api_key: '',
                    payment_gateway_secret_key: '',
                    merchant_upi_id: '',
                    sub_delivery_charge_enabled: false,
                    sub_delivery_charge_name: 'Subscription Delivery',
                    sub_delivery_charge_amount: 0.0,
                    sub_delivery_charge_type: 'FLAT',
                    sub_delivery_charge_gst_percent: 0.0,
                    sub_delivery_free_above: 0.0,
                    enable_salesperson_tagging: false,
                    bill_copies_count: 1,
                    show_brand_name: true,
                    enable_token_system: false,
                    token_copies_count: 1,
                    device_printer_mappings: {},
                    base_currency_code: 'USD',
                    base_currency_symbol: '$',
                    currency_symbol_position: 'BEFORE',
                    currency_decimals: 2,
                    restaurant_settlement_mode: 'DIRECT'
                }
            });
        }

        let settingsData = settings.toJSON ? settings.toJSON() : settings;
        if (!hasInv && !settingsData.allow_negative_stock) {
            settingsData.allow_negative_stock = true;
        }
        if (!settingsData.merchant_upi_id && req.propertyDb.models.property_info) {
            const propInfo = await req.propertyDb.models.property_info.findOne({
                where: { outlet_id }
            }).catch(() => null);
            if (propInfo && propInfo.upi_id) {
                settingsData.merchant_upi_id = propInfo.upi_id;
            }
        }
        if (typeof settingsData.device_printer_mappings === 'string') {
            try {
                settingsData.device_printer_mappings = JSON.parse(settingsData.device_printer_mappings);
            } catch (e) {
                settingsData.device_printer_mappings = {};
            }
        }

        res.json({ success: true, data: settingsData });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveSettings = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const Model = req.propertyDb.models.system_settings;

        const existing = await Model.findOne({
            where: { outlet_id },
            transaction: t
        });

        const oldData = existing ? existing.toJSON() : null;

        let rawMappings = req.body.device_printer_mappings;
        if (typeof rawMappings === 'string') {
            try {
                rawMappings = JSON.parse(rawMappings);
            } catch (e) {
                rawMappings = null;
            }
        }

        const payload: any = {
            outlet_id,
            auto_reorder: req.body.auto_reorder,
            allow_negative_stock: req.body.allow_negative_stock,
            damage_approval_required: req.body.damage_approval_required,
            is_cloud_enabled: req.body.is_cloud_enabled,
            enable_audit_log: req.body.enable_audit_log,
            auto_print_on_save: req.body.auto_print_on_save,
            enable_item_images_in_sales: req.body.enable_item_images_in_sales,
            enable_app_subscription: req.body.enable_app_subscription ?? false,
            print_mode: req.body.print_mode || 'PRINT_DIALOG',
            default_printer_name: req.body.default_printer_name || '',
            default_printer_url: req.body.default_printer_url || '',
            billing_country: req.body.billing_country || 'India',
            time_zone: req.body.time_zone || 'Asia/Kolkata',
            billing_tax_mode: req.body.billing_tax_mode || 'CGST_SGST',
            bill_format: req.body.bill_format || existing?.bill_format || 'A4',
            default_charges: Array.isArray(req.body.default_charges)
                ? req.body.default_charges
                : [],
            voucher_rules: Array.isArray(req.body.voucher_rules)
                ? req.body.voucher_rules
                : (existing?.voucher_rules || []),
            enable_payment_gateway: req.body.enable_payment_gateway ?? false,
            payment_gateway_provider: req.body.payment_gateway_provider || 'SANDBOX',
            payment_gateway_api_key: req.body.payment_gateway_api_key || '',
            payment_gateway_secret_key: req.body.payment_gateway_secret_key || '',
            merchant_upi_id: req.body.merchant_upi_id || '',
            sub_delivery_charge_enabled: req.body.sub_delivery_charge_enabled ?? false,
            sub_delivery_charge_name: req.body.sub_delivery_charge_name || 'Subscription Delivery',
            sub_delivery_charge_amount: req.body.sub_delivery_charge_amount ?? 0.0,
            sub_delivery_charge_type: req.body.sub_delivery_charge_type || 'FLAT',
            sub_delivery_charge_gst_percent: req.body.sub_delivery_charge_gst_percent ?? 0.0,
            sub_delivery_free_above: req.body.sub_delivery_free_above ?? 0.0,
            enable_salesperson_tagging: req.body.enable_salesperson_tagging ?? false,
            bill_copies_count: req.body.bill_copies_count ?? 1,
            show_brand_name: req.body.show_brand_name ?? true,
            enable_token_system: req.body.enable_token_system ?? false,
            token_copies_count: req.body.token_copies_count ?? 1,
            kot_print_mode: req.body.kot_print_mode || 'DIRECT',
            enable_kot_print: req.body.enable_kot_print ?? true,
            base_currency_code: req.body.base_currency_code || 'USD',
            base_currency_symbol: req.body.base_currency_symbol || '$',
            currency_symbol_position: req.body.currency_symbol_position || 'BEFORE',
            currency_decimals: req.body.currency_decimals ?? 2,
            payment_modes: req.body.payment_modes || existing?.payment_modes || [
                { id: 'CASH', name: 'Cash', enabled: true },
                { id: 'CARD', name: 'Card', enabled: true },
                { id: 'MPESA_TILL', name: 'M-Pesa Till', enabled: true },
                { id: 'MPESA_PAYBILL', name: 'M-Pesa Paybill', enabled: true },
                { id: 'BANK_TRANSFER', name: 'Bank Transfer', enabled: true }
            ],
            receipt_template_config: req.body.receipt_template_config || existing?.receipt_template_config || {},
            a4_template_config: req.body.a4_template_config || existing?.a4_template_config || {},
            a5_template_config: req.body.a5_template_config || existing?.a5_template_config || {},
            kot_template_config: req.body.kot_template_config || existing?.kot_template_config || {},
            token_template_config: req.body.token_template_config || existing?.token_template_config || {},
            restaurant_settlement_mode: req.body.restaurant_settlement_mode || existing?.restaurant_settlement_mode || 'DIRECT',
            device_printer_mappings: (rawMappings && typeof rawMappings === 'object' && Object.keys(rawMappings).length > 0)
                ? rawMappings
                : (existing?.device_printer_mappings || {})
        };

        if (req.body.outlet_max_discount_percent !== undefined) {
            payload.outlet_max_discount_percent = req.body.outlet_max_discount_percent;
        }

        let record;
        if (existing) {
            record = await existing.update(payload, { transaction: t });
        } else {
            record = await Model.create(payload, { transaction: t });
        }

        await audit.log({
            req,
            module: 'SYSTEM_SETTINGS',
            action: existing ? 'UPDATE' : 'CREATE',
            table: 'system_settings',
            recordId: record.id,
            oldData,
            newData: record.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        if (req.body.merchant_upi_id !== undefined && req.propertyDb.models.property_info) {
            const propInfo = await req.propertyDb.models.property_info.findOne({
                where: { outlet_id },
                transaction: t
            });
            if (propInfo) {
                await propInfo.update({ upi_id: req.body.merchant_upi_id }, { transaction: t }).catch(() => {});
            }
        }

        await t.commit();

        if (typeof req.body.is_cloud_enabled !== 'undefined') {
            try {
                const { toggleCloudBackup } = require('../../utils/backupTracker');
                const [outletRow]: any = await req.propertyDb.query(
                    'SELECT outlet_code FROM outlets WHERE id = :outlet_id LIMIT 1;',
                    { replacements: { outlet_id } }
                ).catch(() => [[]]);
                const code = (outletRow && outletRow[0] && outletRow[0].outlet_code) || req.user?.outlet_code;
                if (code) {
                    toggleCloudBackup(code, !!req.body.is_cloud_enabled);
                }
            } catch (_) {}
        }

        res.json({ success: true, message: 'Settings saved successfully', data: record });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

const PRESERVED_MODELS = new Set([
    'schema_version',
    'system_settings',
    'item_master',
    'item_masters',
    'categories',
    'category_master',
    'brands',
    'brand_master',
    'units',
    'unit_master',
    'groups',
    'group_master',
    'subcategories',
    'subcategory_master',
    'customers',
    'customer',
    'users',
    'user',
    'outlets',
    'outlet',
    'app_branding',
    'dining_tables',
    'dining_areas',
    'floors',
    'email_configs',
    'email_templates',
    'feature_modules',
    'licenses',
    'owners',
    'properties',
    'attributes',
    'attribute_values',
    'hsn_master'
]);

exports.clearTransactionData = async (req, res) => {
    try {
        let outletId = Number(
            req.body?.outlet_id ||
            req.body?.outletId ||
            req.outlet_id ||
            req.user?.outlet_id ||
            req.headers['x-outlet-id'] ||
            req.query?.outlet_id ||
            0
        );

        let outletCode = String(
            req.body?.outlet_code ||
            req.body?.outletCode ||
            req.outlet_code ||
            req.user?.outlet_code ||
            req.headers['x-outlet-code'] ||
            ''
        ).trim();

        if (outletCode) {
            try {
                const [oRow]: any = await req.propertyDb.query(
                    `SELECT id, outlet_code FROM outlets WHERE outlet_code = :code LIMIT 1;`,
                    { replacements: { code: outletCode }, type: QueryTypes.SELECT }
                );
                if (oRow && oRow.id) {
                    outletId = Number(oRow.id);
                    outletCode = String(oRow.outlet_code || outletCode);
                }
            } catch (_) {}
        } else if (outletId) {
            try {
                const [oRow]: any = await req.propertyDb.query(
                    `SELECT id, outlet_code FROM outlets WHERE id = :id LIMIT 1;`,
                    { replacements: { id: outletId }, type: QueryTypes.SELECT }
                );
                if (oRow && oRow.outlet_code) {
                    outletCode = String(oRow.outlet_code);
                }
            } catch (_) {}
        }
        if (!outletId) outletId = 1;
        if (!outletCode) outletCode = `OUT_${outletId}`;

        if (!outletId || isNaN(outletId)) {
            return res.status(400).json({
                success: false,
                message: 'Outlet ID is required to manage transaction data'
            });
        }

        const isDryRun = req.body?.dry_run === true || req.query?.dry_run === 'true';
        const retentionType = req.body?.date_filter_type || (req.body?.older_than_years ? 'OLDER_THAN' : 'ALL_TIME');
        const olderThanYears = Number(req.body?.older_than_years || 5);
        const startDate = req.body?.start_date;
        const endDate = req.body?.end_date;
        const modules = Array.isArray(req.body?.modules) && req.body.modules.length > 0 ? req.body.modules : ['ALL'];

        // MODE 1: DRY RUN PREVIEW (Before user clicks delete)
        if (isDryRun) {
            const preview = await DataRetentionService.previewRetentionPurge(req.propertyDb, {
                outletId,
                outletCode,
                allOutlets: false,
                retentionType,
                olderThanYears,
                startDate,
                endDate,
                modules,
            });

            return res.json({
                success: true,
                dry_run: true,
                preview,
                outlet_id: outletId,
                outlet_code: outletCode,
            });
        }

        // MODE 2: ACTUAL RETENTION PURGE EXECUTION
        const confirmText = String(req.body.confirm_text || '').trim().toUpperCase();
        if (confirmText !== 'DELETE ALL DATA' && confirmText !== 'DELETE CONFIRMED') {
            return res.status(400).json({
                success: false,
                message: 'Type DELETE CONFIRMED to execute transactional data purge.'
            });
        }

        const createBackupFirst = req.body?.backup_first !== false;
        const recipientEmail = String(req.body?.recipient_email || req.user?.email || '').trim();

        const result = await DataRetentionService.executeRetentionPurge(req.propertyDb, {
            outletId,
            outletCode,
            allOutlets: req.body?.allOutlets === true || req.body?.all_outlets === true,
            retentionType,
            olderThanYears,
            startDate,
            endDate,
            modules,
            createBackupFirst,
            recipientEmail: recipientEmail || undefined,
            req,
        });

        try {
            await audit.log(req, 'CLEAR_TRANSACTION_DATA', {
                details: `Pruned ${result.totalDeletedRecords} records for outlet #${outletId} (${result.retentionPolicy})`
            });
        } catch (_) {}

        return res.json({
            success: true,
            message: `Cleared ${result.totalDeletedRecords.toLocaleString()} records for outlet ${outletCode} successfully (${result.retentionPolicy}).`,
            outlet_id: outletId,
            outlet_code: outletCode,
            total_deleted: result.totalDeletedRecords,
            tables_affected: result.tablesAffected,
            retention_policy: result.retentionPolicy,
            backup_secured: Boolean(result.backupResult),
            backup_filename: result.backupResult?.filename,
            preserved: ['catalogs', 'customers_master', 'system_settings', 'other_outlets_data']
        });
    } catch (err) {
        console.error("❌ Error clearing transaction data:", err);
        return res.status(500).json({ success: false, message: err.message || 'Failed to clear transaction data' });
    }
};


exports.getOnboardingStatus = async (req: any, res: any) => {
    try {
        let outletId = req.user?.outlet_id || req.query?.outlet_id || req.body?.outlet_id;
        const db = req.propertyDb;

        if (typeof outletId === 'string' && outletId.startsWith('OUTLET') && db.models.outlets) {
            const outlet = await db.models.outlets.findOne({ where: { outlet_code: outletId } }).catch(() => null);
            if (outlet) outletId = outlet.id;
        }

        if (!outletId && db.models.outlets) {
            const defaultOutlet = await db.models.outlets.findOne({ where: { is_active: true } }).catch(() => null);
            if (defaultOutlet) outletId = defaultOutlet.id;
        }

        outletId = parseInt(outletId, 10) || 1;

        const [
            propInfo,
            systemSettings,
            taxGroupsCount,
            sequencesCount,
            locationsCount,
            itemsCount,
            suppliersCount,
            tablesCount,
            usersCount,
            outletObj
        ] = await Promise.all([
            db.models.property_info ? db.models.property_info.findOne({
                where: { outlet_id: outletId },
                attributes: ['property_name', 'business_type']
            }).catch(() => null) : null,
            db.models.system_settings ? db.models.system_settings.findOne({
                where: { outlet_id: outletId },
                attributes: ['base_currency_symbol', 'billing_country']
            }).catch(() => null) : null,
            db.models.tax_groups ? db.models.tax_groups.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.numbering_settings ? db.models.numbering_settings.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.stock_locations ? db.models.stock_locations.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.item_master ? db.models.item_master.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.supplier_master ? db.models.supplier_master.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.restaurant_tables ? db.models.restaurant_tables.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.users ? db.models.users.count({ where: { outlet_id: outletId } }).catch(() => 0) : 0,
            db.models.outlets ? db.models.outlets.findByPk(outletId).catch(() => null) : null
        ]);

        const propConfigured = !!(
            (propInfo?.property_name && propInfo.property_name.toString().trim().length > 0) ||
            (outletObj?.outlet_name && outletObj.outlet_name.toString().trim().length > 0)
        );
        const settingsConfigured = !!(systemSettings && (systemSettings.base_currency_symbol || systemSettings.billing_country));
        const taxGroupConfigured = (taxGroupsCount > 0);
        const sequenceConfigured = (sequencesCount > 0);
        const locationConfigured = (locationsCount > 0);
        const itemMasterConfigured = (itemsCount > 0);
        const supplierConfigured = (suppliersCount > 0);
        const restaurantConfigured = (tablesCount > 0);
        const usersConfigured = (usersCount > 1);

        const businessType = resolveBusinessModule(
            outletObj?.business_module || req.user?.business_module,
            propInfo?.business_type || req.user?.outlet_type || outletObj?.outlet_type
        );

        res.json({
            success: true,
            data: {
                business_module: businessType,
                property_configured: propConfigured,
                settings_configured: settingsConfigured,
                tax_group_configured: taxGroupConfigured,
                sequence_configured: sequenceConfigured,
                location_configured: locationConfigured,
                item_master_configured: itemMasterConfigured,
                supplier_configured: supplierConfigured,
                restaurant_configured: restaurantConfigured,
                users_configured: usersConfigured
            }
        });
    } catch (err: any) {
        console.error('[ONBOARDING STATUS ERROR]', err);
        res.status(500).json({ success: false, message: 'Failed to fetch onboarding status: ' + err.message });
    }
};

module.exports = exports;
export default exports;
