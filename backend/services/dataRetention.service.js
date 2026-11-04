"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DataRetentionService = exports.RETENTION_TABLES = void 0;
const sequelize_1 = require("sequelize");
const tenantBackup_service_1 = __importDefault(require("./tenantBackup.service"));
exports.RETENTION_TABLES = [
    // 1. Restaurant / KOT child & header tables
    { table: 'kot_revisions', module: 'SALES', isChild: true, parentTable: 'kot_headers', parentFk: 'kot_header_id' },
    { table: 'kot_items', module: 'SALES', isChild: true, parentTable: 'kot_headers', parentFk: 'kot_header_id' },
    { table: 'kot_headers', module: 'SALES', dateColumn: 'created_at' },
    { table: 'restaurant_audit_trail', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'table_reservations', module: 'SALES', dateColumn: 'created_at' },
    // 2. Lucky Draw Campaign & WhatsApp tables
    { table: 'draw_vouchers', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'customer_draw_progress', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'lucky_draw_campaigns', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'whatsapp_logs', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'whatsapp_campaigns', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    // 3. Supplier Returns & Goods Receipts
    { table: 'supplier_return_refunds', module: 'PURCHASES', isChild: true, parentTable: 'supplier_return_headers', parentFk: 'return_id' },
    { table: 'supplier_return_items', module: 'PURCHASES', isChild: true, parentTable: 'supplier_return_headers', parentFk: 'return_id' },
    { table: 'supplier_return_headers', module: 'PURCHASES', dateColumn: 'created_at' },
    { table: 'goods_receipt_items', module: 'PURCHASES', isChild: true, parentTable: 'goods_receipts', parentFk: 'grn_id' },
    { table: 'goods_receipts', module: 'PURCHASES', dateColumn: 'created_at' },
    { table: 'supplier_payments', module: 'PURCHASES', dateColumn: 'created_at' },
    { table: 'supplier_bills', module: 'PURCHASES', dateColumn: 'created_at' },
    // 4. Purchase Orders
    { table: 'purchase_order_items', module: 'PURCHASES', isChild: true, parentTable: 'purchase_orders', parentFk: 'po_id' },
    { table: 'purchase_orders', module: 'PURCHASES', dateColumn: 'created_at' },
    // 5. Stock Issues / Returns / Damages / Assembly / Requests / Delivery Challans
    { table: 'return_items', module: 'INVENTORY', isChild: true, parentTable: 'return_headers', parentFk: 'return_id' },
    { table: 'return_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'issue_items', module: 'INVENTORY', isChild: true, parentTable: 'issue_headers', parentFk: 'issue_id' },
    { table: 'issue_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'damage_items', module: 'INVENTORY', isChild: true, parentTable: 'damage_headers', parentFk: 'damage_id' },
    { table: 'damage_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'assembly_items', module: 'INVENTORY', isChild: true, parentTable: 'assembly_headers', parentFk: 'assembly_id' },
    { table: 'assembly_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'request_items', module: 'INVENTORY', isChild: true, parentTable: 'request_headers', parentFk: 'request_id' },
    { table: 'request_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'delivery_challan_items', module: 'INVENTORY', isChild: true, parentTable: 'delivery_challan_headers', parentFk: 'challan_id' },
    { table: 'delivery_challan_headers', module: 'INVENTORY', dateColumn: 'created_at' },
    // 6. Milk Subscriptions
    { table: 'milk_subscription_consumptions', module: 'SALES', dateColumn: 'created_at' },
    { table: 'milk_subscription_settlements', module: 'SALES', dateColumn: 'created_at' },
    { table: 'milk_subscription_schemes', module: 'SALES', dateColumn: 'created_at' },
    { table: 'milk_subscriptions', module: 'SALES', dateColumn: 'created_at' },
    // 7. HRMS Transactional Tables
    { table: 'hr_loan_transactions', module: 'HRMS', isChild: true, parentTable: 'hr_loans', parentFk: 'loan_id' },
    { table: 'hr_loans', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_sales_commissions', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_cashier_handovers', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_payroll_details', module: 'HRMS', isChild: true, parentTable: 'hr_payroll_runs', parentFk: 'payroll_run_id' },
    { table: 'hr_payroll_runs', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_salary_revisions', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_arrears', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_attendance_punches', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_leave_balances', module: 'HRMS', dateColumn: 'created_at' },
    { table: 'hr_leave_applications', module: 'HRMS', dateColumn: 'created_at' },
    // 8. Sales & Customer Transactions
    { table: 'sales_items', module: 'SALES', isChild: true, parentTable: 'sales_headers', parentFk: 'sale_id' },
    { table: 'sales_refunds', module: 'SALES', isChild: true, parentTable: 'sales_headers', parentFk: 'sale_id' },
    { table: 'sales_credit_notes', module: 'SALES', dateColumn: 'created_at' },
    { table: 'customer_repayments', module: 'SALES', dateColumn: 'created_at' },
    { table: 'customer_item_advances', module: 'SALES', dateColumn: 'created_at' },
    { table: 'customer_advances', module: 'SALES', dateColumn: 'created_at' },
    { table: 'customer_orders', module: 'SALES', dateColumn: 'created_at' },
    { table: 'sales_headers', module: 'SALES', dateColumn: 'created_at' },
    { table: 'sales_scheme_customers', module: 'SALES', dateColumn: 'created_at' },
    { table: 'customer_loyalty_ledger', module: 'SALES', dateColumn: 'created_at' },
    // 9. Finance, Expenses & Accounting
    { table: 'cash_ledger', module: 'FINANCE', dateColumn: 'created_at' },
    { table: 'expense_taxes', module: 'FINANCE', isChild: true, parentTable: 'expenses', parentFk: 'expense_id' },
    { table: 'expense_deductions', module: 'FINANCE', isChild: true, parentTable: 'expenses', parentFk: 'expense_id' },
    { table: 'expense_entries', module: 'FINANCE', dateColumn: 'created_at' },
    { table: 'expenses', module: 'FINANCE', dateColumn: 'created_at' },
    { table: 'daily_opening_balances', module: 'FINANCE', dateColumn: 'created_at' },
    { table: 'accounting_vouchers', module: 'FINANCE', dateColumn: 'created_at' },
    // 10. Stock Ledger, Notifications, Audits, Night Audit
    { table: 'stock_ledger', module: 'INVENTORY', dateColumn: 'created_at' },
    { table: 'system_notifications', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'audit_logs', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
    { table: 'night_audit_details', module: 'AUDIT_LOGS', isChild: true, parentTable: 'night_audit_runs', parentFk: 'audit_run_id' },
    { table: 'night_audit_runs', module: 'AUDIT_LOGS', dateColumn: 'created_at' },
];
class DataRetentionService {
    /**
     * Helper: Builds SQL WHERE clause fragment for outlet and date range
     */
    static buildFilterClause(def, options, replacements) {
        const isAllOutlets = options.allOutlets === true;
        const outletId = Number(options.outletId || 1);
        const conditions = [];
        // 1. Outlet Scoping
        if (!isAllOutlets) {
            if (def.isChild && def.parentTable && def.parentFk) {
                // Child table scoped through parent
                conditions.push(`"${def.parentFk}" IN (SELECT id FROM "${def.parentTable}" WHERE outlet_id = :outletId)`);
            }
            else {
                conditions.push(`outlet_id = :outletId`);
            }
            replacements.outletId = outletId;
        }
        // 2. Date Filtering
        const retType = options.retentionType || (options.olderThanYears ? 'OLDER_THAN' : 'ALL_TIME');
        if (retType === 'OLDER_THAN') {
            const years = Number(options.olderThanYears || 5);
            const cutoffDate = new Date(Date.now() - years * 365.25 * 24 * 60 * 60 * 1000).toISOString();
            replacements.cutoffDate = cutoffDate;
            if (def.isChild && def.parentTable && def.parentFk) {
                conditions.push(`"${def.parentFk}" IN (SELECT id FROM "${def.parentTable}" WHERE created_at < :cutoffDate)`);
            }
            else {
                conditions.push(`created_at < :cutoffDate`);
            }
        }
        else if (retType === 'DATE_RANGE') {
            if (options.startDate) {
                replacements.startDate = new Date(options.startDate).toISOString();
                if (def.isChild && def.parentTable && def.parentFk) {
                    conditions.push(`"${def.parentFk}" IN (SELECT id FROM "${def.parentTable}" WHERE created_at >= :startDate)`);
                }
                else {
                    conditions.push(`created_at >= :startDate`);
                }
            }
            if (options.endDate) {
                replacements.endDate = new Date(options.endDate).toISOString();
                if (def.isChild && def.parentTable && def.parentFk) {
                    conditions.push(`"${def.parentFk}" IN (SELECT id FROM "${def.parentTable}" WHERE created_at <= :endDate)`);
                }
                else {
                    conditions.push(`created_at <= :endDate`);
                }
            }
        }
        return conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    }
    /**
     * Helper: Filter table definitions by requested modules
     */
    static getSelectedTables(modules) {
        if (!modules || modules.length === 0 || modules.includes('ALL')) {
            return exports.RETENTION_TABLES;
        }
        const set = new Set(modules.map(m => m.toUpperCase()));
        return exports.RETENTION_TABLES.filter(t => set.has(t.module.toUpperCase()));
    }
    /**
     * 1. Dry-Run Retention Preview
     * Counts how many records will be deleted without touching the database.
     */
    static async previewRetentionPurge(activeDb, options) {
        const selectedTables = this.getSelectedTables(options.modules);
        const breakdown = [];
        let totalMatchingRecords = 0;
        for (const def of selectedTables) {
            const replacements = {};
            const whereClause = this.buildFilterClause(def, options, replacements);
            const queryStr = `SELECT COUNT(*) as count FROM "${def.table}" ${whereClause};`;
            try {
                const rows = await activeDb.query(queryStr, {
                    replacements,
                    type: sequelize_1.QueryTypes.SELECT
                }).catch(() => [{ count: 0 }]);
                const count = Number(rows?.[0]?.count || 0);
                if (count > 0) {
                    breakdown.push({
                        table: def.table,
                        module: def.module,
                        count
                    });
                    totalMatchingRecords += count;
                }
            }
            catch (_) {
                // Table may not exist in specific tenant schemas
            }
        }
        const retType = options.retentionType || (options.olderThanYears ? 'OLDER_THAN' : 'ALL_TIME');
        let policyDesc = 'All Historical Records';
        if (retType === 'OLDER_THAN') {
            policyDesc = `Older than ${options.olderThanYears || 5} Years (Statutory Retention Policy)`;
        }
        else if (retType === 'DATE_RANGE') {
            policyDesc = `Custom Date Range: ${options.startDate || 'Start'} to ${options.endDate || 'End'}`;
        }
        return {
            totalMatchingRecords,
            breakdown,
            scope: options.allOutlets ? 'ENTERPRISE_ALL_OUTLETS' : `OUTLET_${options.outletCode || options.outletId || 'SELECTED'}`,
            retentionPolicy: policyDesc,
        };
    }
    /**
     * 2. Execute Retention Purge
     * Executes deletion inside a safe rollback-capable database transaction.
     * If createBackupFirst is true, creates a complete backup archive before deletion.
     */
    static async executeRetentionPurge(activeDb, options) {
        const isAllOutlets = options.allOutlets === true;
        const outletId = Number(options.outletId || 1);
        const outletCode = options.outletCode || `OUT_${outletId}`;
        // STEP 1: Mandatory / Optional Safety Backup Snapshot
        let backupResult = null;
        if (options.createBackupFirst !== false) {
            console.log(`🛡️ [RETENTION] Generating pre-purge safety backup snapshot before deleting data...`);
            try {
                backupResult = await tenantBackup_service_1.default.createFambakBackup(activeDb, {
                    scope: isAllOutlets ? 'ALL' : 'OUTLET',
                    outletId,
                    outletCode,
                    saveToDrive: true,
                });
                // If email provided, send recovery email with link
                if (options.recipientEmail && options.req) {
                    const { BackupManagementController } = require('../controllers/backup/backupManagement.controller');
                    await BackupManagementController.sendDisasterRecoveryEmail({
                        activeDb,
                        filePath: backupResult.filePath,
                        filename: backupResult.filename,
                        recipientEmail: options.recipientEmail,
                        outletCode,
                        outletId,
                        req: options.req,
                        scope: isAllOutlets ? 'ALL' : 'OUTLET',
                    }).catch((e) => console.warn('Pre-purge email link warning:', e.message));
                }
            }
            catch (backupErr) {
                console.error('❌ [RETENTION] Safety backup failed:', backupErr.message);
                throw new Error(`Safety backup failed prior to purge. Aborting deletion for data security: ${backupErr.message}`);
            }
        }
        // STEP 2: Execute Scoped Deletions in Safe Database Transaction
        const selectedTables = this.getSelectedTables(options.modules);
        let totalDeletedRecords = 0;
        const breakdown = [];
        await activeDb.transaction(async (t) => {
            // Child tables first, parents last
            for (const def of selectedTables) {
                const replacements = {};
                const whereClause = this.buildFilterClause(def, options, replacements);
                const queryStr = `DELETE FROM "${def.table}" ${whereClause};`;
                try {
                    const [, meta] = await activeDb.query(queryStr, {
                        replacements,
                        transaction: t,
                    });
                    const rowCount = typeof meta === 'number' ? meta : (meta?.rowCount || 0);
                    if (rowCount > 0) {
                        breakdown.push({ table: def.table, deleted: rowCount });
                        totalDeletedRecords += rowCount;
                    }
                }
                catch (delErr) {
                    console.warn(`[RETENTION] Warning deleting from ${def.table}: ${delErr.message}`);
                }
            }
            // Realign bank account opening balances if all finance was cleared
            if (options.modules?.includes('FINANCE') || options.modules?.includes('ALL') || !options.modules) {
                try {
                    const bankWhere = isAllOutlets ? '' : 'WHERE outlet_id = :outletId';
                    await activeDb.query(`UPDATE "bank_accounts" SET opening_balance = 0.00, current_balance = 0.00 ${bankWhere};`, { replacements: { outletId }, transaction: t });
                }
                catch (_) { }
            }
        });
        const retType = options.retentionType || (options.olderThanYears ? 'OLDER_THAN' : 'ALL_TIME');
        let policyDesc = 'All Historical Records';
        if (retType === 'OLDER_THAN') {
            policyDesc = `Older than ${options.olderThanYears || 5} Years`;
        }
        else if (retType === 'DATE_RANGE') {
            policyDesc = `Date Range: ${options.startDate} to ${options.endDate}`;
        }
        console.log(`✅ [RETENTION] Purge completed successfully: ${totalDeletedRecords.toLocaleString()} records removed.`);
        return {
            success: true,
            totalDeletedRecords,
            tablesAffected: breakdown.length,
            backupResult,
            breakdown,
            retentionPolicy: policyDesc,
        };
    }
    /**
     * 3. Automated 5-Year Cloud Data Retention Policy Runner
     * Prunes transactional data older than 5 years enterprise-wide or per outlet.
     */
    static async applyAutomated5YearPolicy(activeDb, options) {
        return this.executeRetentionPurge(activeDb, {
            allOutlets: options.allOutlets ?? false,
            outletId: options.outletId,
            outletCode: options.outletCode,
            retentionType: 'OLDER_THAN',
            olderThanYears: 5,
            modules: ['ALL'],
            createBackupFirst: options.createBackupFirst !== false,
        });
    }
}
exports.DataRetentionService = DataRetentionService;
exports.default = DataRetentionService;
module.exports = DataRetentionService;
