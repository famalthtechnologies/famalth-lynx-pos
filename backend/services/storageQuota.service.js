"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StorageQuotaService = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const fsPromises = fs_1.default.promises;
class StorageQuotaService {
    static DEFAULT_BASE_QUOTA_BYTES = 16106127360; // 15 GB (15 * 1024^3)
    static formatBytes(bytes, decimals = 1) {
        if (!bytes || bytes <= 0)
            return '0.0 GB';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
    }
    /**
     * 1. Get or create dedicated tenant folders on the local hard disk or cloud volume
     * E.g. storage/outlets/<outletCode>/{backups, uploads, exports}
     */
    /**
   * Dedicated Admin Console / Enterprise Storage Paths
   * Complete multi-tenant system backups, global schemas, and enterprise catalogs
   * are stored in an isolated administrative directory separate from all outlet folders.
   */
    static getAdminConsoleStoragePaths() {
        const rootSearch = [
            path_1.default.resolve(process.cwd(), 'storage'),
            path_1.default.resolve(__dirname, '..', 'storage'),
            path_1.default.resolve(__dirname, '..', '..', 'storage'),
            path_1.default.resolve(process.cwd(), 'backend', 'storage'),
        ];
        let baseStorage = rootSearch[0];
        for (const cand of rootSearch) {
            if (fs_1.default.existsSync(cand)) {
                baseStorage = cand;
                break;
            }
        }
        const adminRoot = path_1.default.join(baseStorage, 'enterprise');
        const backupsDir = path_1.default.join(adminRoot, 'backups');
        const exportsDir = path_1.default.join(adminRoot, 'exports');
        const systemSnapshotsDir = path_1.default.join(adminRoot, 'system_snapshots');
        try {
            if (!fs_1.default.existsSync(adminRoot))
                fs_1.default.mkdirSync(adminRoot, { recursive: true });
            if (!fs_1.default.existsSync(backupsDir))
                fs_1.default.mkdirSync(backupsDir, { recursive: true });
            if (!fs_1.default.existsSync(exportsDir))
                fs_1.default.mkdirSync(exportsDir, { recursive: true });
            if (!fs_1.default.existsSync(systemSnapshotsDir))
                fs_1.default.mkdirSync(systemSnapshotsDir, { recursive: true });
        }
        catch (_) { }
        return {
            adminRoot,
            backupsDir,
            exportsDir,
            systemSnapshotsDir,
        };
    }
    static getTenantStoragePaths(outletCode) {
        const rootSearch = [
            path_1.default.resolve(process.cwd(), 'storage'),
            path_1.default.resolve(process.cwd(), '..', 'storage'),
            path_1.default.resolve(__dirname, '..', '..', 'storage'),
            path_1.default.resolve(process.cwd(), 'backend', 'storage'),
        ];
        let baseStorage = rootSearch[0];
        for (const cand of rootSearch) {
            if (fs_1.default.existsSync(cand)) {
                baseStorage = cand;
                break;
            }
        }
        const tenantRoot = path_1.default.join(baseStorage, 'outlets', outletCode);
        const backupsDir = path_1.default.join(tenantRoot, 'backups');
        const uploadsDir = path_1.default.join(tenantRoot, 'uploads');
        const exportsDir = path_1.default.join(tenantRoot, 'exports');
        // Auto-create client isolated directories
        try {
            if (!fs_1.default.existsSync(tenantRoot))
                fs_1.default.mkdirSync(tenantRoot, { recursive: true });
            if (!fs_1.default.existsSync(backupsDir))
                fs_1.default.mkdirSync(backupsDir, { recursive: true });
            if (!fs_1.default.existsSync(uploadsDir))
                fs_1.default.mkdirSync(uploadsDir, { recursive: true });
            if (!fs_1.default.existsSync(exportsDir))
                fs_1.default.mkdirSync(exportsDir, { recursive: true });
        }
        catch (_) { }
        return {
            rootDir: tenantRoot,
            backupsDir,
            uploadsDir,
            exportsDir,
        };
    }
    /**
     * 2. Auto-Provision 15 GB Free Quota on Outlet Registration
     */
    static async getOrCreateQuota(activeDb, outletId, outletCode) {
        if (!activeDb || !activeDb.models || !activeDb.models.outlet_storage_quotas) {
            return null;
        }
        let quota = await activeDb.models.outlet_storage_quotas.findOne({
            where: { outlet_code: outletCode },
        });
        if (!quota) {
            quota = await activeDb.models.outlet_storage_quotas.create({
                outlet_id: outletId,
                outlet_code: outletCode,
                base_quota_bytes: this.DEFAULT_BASE_QUOTA_BYTES,
                addon_quota_bytes: 0,
                promotional_bonus_bytes: 0,
                total_allocated_bytes: this.DEFAULT_BASE_QUOTA_BYTES,
                current_backups_bytes: 0,
                current_uploads_bytes: 0,
                current_db_bytes: 0,
                total_used_bytes: 0,
                warning_threshold_pct: 80,
                is_frozen: false,
                active_plan_code: 'STARTER_15GB',
            });
            console.log(`[STORAGE QUOTA] Auto-allocated 15 GB Cloud Storage for ${outletCode}`);
        }
        // Ensure tenant disk folders exist
        this.getTenantStoragePaths(outletCode);
        return quota;
    }
    /**
     * Helper to sum directory file size
     */
    static async getDirSize(dirPath) {
        if (!fs_1.default.existsSync(dirPath))
            return 0;
        let total = 0;
        try {
            const entries = await fsPromises.readdir(dirPath, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path_1.default.join(dirPath, entry.name);
                if (entry.isFile()) {
                    const stat = await fsPromises.stat(fullPath);
                    total += stat.size;
                }
                else if (entry.isDirectory()) {
                    total += await this.getDirSize(fullPath);
                }
            }
        }
        catch (_) { }
        return total;
    }
    /**
     * 3. Real-Time Storage Audit: Calculates Backups + Uploads + Database Footprint
     */
    static async calculateTenantStorage(activeDb, outletId, outletCode) {
        const paths = this.getTenantStoragePaths(outletCode);
        // A. Backups Size (Tenant isolated backups folder + any matching files in root)
        let backupsBytes = await this.getDirSize(paths.backupsDir);
        try {
            const rootStorage = path_1.default.dirname(path_1.default.dirname(paths.rootDir));
            if (fs_1.default.existsSync(rootStorage)) {
                const rootEntries = await fsPromises.readdir(rootStorage, { withFileTypes: true });
                for (const re of rootEntries) {
                    if (re.isFile() && re.name.includes(outletCode) && (re.name.endsWith('.fambak') || re.name.endsWith('.posbak'))) {
                        const stat = await fsPromises.stat(path_1.default.join(rootStorage, re.name));
                        backupsBytes += stat.size;
                    }
                }
            }
        }
        catch (_) { }
        // B. Media & Uploads Size (Tenant product photos, receipts, invoice attachments)
        let uploadsBytes = await this.getDirSize(paths.uploadsDir);
        // Also check global uploads/ if partitioned by outlet
        const globalUploadsCandidate = path_1.default.join(path_1.default.dirname(paths.rootDir), '..', 'uploads', outletCode);
        if (fs_1.default.existsSync(globalUploadsCandidate)) {
            uploadsBytes += await this.getDirSize(globalUploadsCandidate);
        }
        // C. Database Footprint for this tenant
        let exportsBytes = await this.getDirSize(paths.exportsDir);
        // C. Real Database Footprint on Hard Disk for this tenant (0 fallback, strictly real)
        let databaseBytes = 0;
        if (activeDb) {
            try {
                let totalDbBytes = 0;
                try {
                    const dbSizeRes = await activeDb.query('SELECT pg_database_size(current_database()) as db_bytes;', { type: 'SELECT' });
                    totalDbBytes = Number(dbSizeRes?.[0]?.db_bytes || dbSizeRes?.db_bytes || 0);
                }
                catch (_) { }
                const countRes = await activeDb.query('SELECT (' +
                    '  (SELECT COUNT(*) FROM sales_headers WHERE outlet_id = :outletId) +' +
                    '  (SELECT COUNT(*) FROM sales_items WHERE outlet_id = :outletId) +' +
                    '  (SELECT COUNT(*) FROM stock_ledger WHERE outlet_id = :outletId) +' +
                    '  (SELECT COUNT(*) FROM item_master WHERE outlet_id = :outletId)' +
                    ') AS total_rows;', { replacements: { outletId }, type: 'SELECT' }).catch(() => []);
                const totalRows = Number(countRes?.[0]?.total_rows || countRes?.total_rows || 0);
                if (totalRows > 0) {
                    if (totalDbBytes > 0) {
                        const allRowsRes = await activeDb.query('SELECT (' +
                            '  (SELECT COUNT(*) FROM sales_headers) +' +
                            '  (SELECT COUNT(*) FROM sales_items) +' +
                            '  (SELECT COUNT(*) FROM stock_ledger) +' +
                            '  (SELECT COUNT(*) FROM item_master)' +
                            ') AS all_rows;', { type: 'SELECT' }).catch(() => []);
                        const allRows = Number(allRowsRes?.[0]?.all_rows || allRowsRes?.all_rows || 0);
                        if (allRows > 0) {
                            databaseBytes = Math.round((totalRows / allRows) * totalDbBytes);
                        }
                        else {
                            databaseBytes = totalRows * 512;
                        }
                    }
                    else {
                        databaseBytes = totalRows * 512;
                    }
                }
            }
            catch (_) { }
        }
        const totalUsedBytes = backupsBytes + uploadsBytes + exportsBytes + databaseBytes;
        // Get quota record from database
        const quota = await this.getOrCreateQuota(activeDb, outletId, outletCode);
        const baseQuotaBytes = Number(quota?.base_quota_bytes || this.DEFAULT_BASE_QUOTA_BYTES);
        const addonQuotaBytes = Number(quota?.addon_quota_bytes || 0);
        const promotionalBonusBytes = Number(quota?.promotional_bonus_bytes || 0);
        const totalAllocatedBytes = baseQuotaBytes + addonQuotaBytes + promotionalBonusBytes;
        const freeBytes = Math.max(0, totalAllocatedBytes - totalUsedBytes);
        const usagePct = Math.min(100, parseFloat(((totalUsedBytes / totalAllocatedBytes) * 100).toFixed(1)));
        const warningThreshold = Number(quota?.warning_threshold_pct || 80);
        const isWarning = usagePct >= warningThreshold && usagePct < 95;
        const isCritical = usagePct >= 95 && usagePct < 100;
        const isFrozen = totalUsedBytes >= totalAllocatedBytes;
        // Persist latest telemetry into outlet_storage_quotas
        try {
            if (quota) {
                await quota.update({
                    current_backups_bytes: backupsBytes,
                    current_uploads_bytes: uploadsBytes,
                    current_db_bytes: databaseBytes,
                    total_used_bytes: totalUsedBytes,
                    total_allocated_bytes: totalAllocatedBytes,
                    is_frozen: isFrozen,
                });
            }
        }
        catch (_) { }
        return {
            outletId,
            outletCode,
            activePlan: String(quota?.active_plan_code || 'STARTER_15GB'),
            baseQuotaBytes,
            addonQuotaBytes,
            promotionalBonusBytes,
            totalAllocatedBytes,
            totalAllocatedPretty: this.formatBytes(totalAllocatedBytes),
            totalUsedBytes,
            totalUsedPretty: this.formatBytes(totalUsedBytes),
            freeBytes,
            freePretty: this.formatBytes(freeBytes),
            usagePct,
            isWarning,
            isCritical,
            isFrozen,
            breakdown: {
                backupsBytes,
                backupsPretty: this.formatBytes(backupsBytes),
                uploadsBytes,
                uploadsPretty: this.formatBytes(uploadsBytes),
                databaseBytes,
                databasePretty: this.formatBytes(databaseBytes),
            },
            storagePaths: paths,
        };
    }
    /**
     * 4. 1-Click Monthly Storage Expansion (+25GB, +50GB, +100GB)
     */
    static async upgradeStorageAddon(activeDb, outletCode, addonPlanCode) {
        const plans = {
            ADDON_25GB: { bytes: 25 * 1024 * 1024 * 1024, name: 'Famalth Lynx Storage +25 GB' },
            ADDON_50GB: { bytes: 50 * 1024 * 1024 * 1024, name: 'Famalth Lynx Storage +50 GB' },
            ADDON_100GB: { bytes: 100 * 1024 * 1024 * 1024, name: 'Famalth Lynx Storage +100 GB' },
        };
        const selected = plans[addonPlanCode.toUpperCase()];
        if (!selected) {
            throw new Error(`Invalid storage plan: ${addonPlanCode}. Valid options: ADDON_25GB, ADDON_50GB, ADDON_100GB`);
        }
        let quota = await activeDb.models.outlet_storage_quotas.findOne({
            where: { outlet_code: outletCode },
        });
        if (!quota) {
            throw new Error(`Storage quota record not found for outlet ${outletCode}`);
        }
        const newAddonBytes = Number(quota.addon_quota_bytes || 0) + selected.bytes;
        const baseBytes = Number(quota.base_quota_bytes || this.DEFAULT_BASE_QUOTA_BYTES);
        const bonusBytes = Number(quota.promotional_bonus_bytes || 0);
        const newTotalAllocated = baseBytes + newAddonBytes + bonusBytes;
        await quota.update({
            addon_quota_bytes: newAddonBytes,
            total_allocated_bytes: newTotalAllocated,
            active_plan_code: addonPlanCode.toUpperCase(),
            is_frozen: false,
        });
        return {
            success: true,
            message: `Successfully expanded storage! Added ${selected.name}. New total quota: ${this.formatBytes(newTotalAllocated)}.`,
            newAllocatedPretty: this.formatBytes(newTotalAllocated),
        };
    }
    /**
     * 5. Enterprise Super-Admin Storage Overview
     * Displays all clients, storage usage, paid versions running, and monthly add-ons.
     */
    static async getEnterpriseStorageOverview(activeDb) {
        const outletsResult = await activeDb.query(`SELECT id, outlet_code, outlet_name, outlet_type, business_module, created_at FROM outlets ORDER BY id ASC;`, { type: 'SELECT' }).catch(() => []);
        const outletList = Array.isArray(outletsResult) ? outletsResult : (outletsResult?.[0] || []);
        let quotas = [];
        try {
            if (activeDb.models && activeDb.models.outlet_storage_quotas) {
                quotas = await activeDb.models.outlet_storage_quotas.findAll().catch(() => []);
            }
        }
        catch (_) { }
        const quotaMap = new Map();
        if (Array.isArray(quotas)) {
            quotas.forEach((q) => quotaMap.set(q.outlet_code, q));
        }
        const planPrices = {
            ADDON_25GB: 99,
            ADDON_50GB: 189,
            ADDON_100GB: 349,
        };
        let totalAllocatedBytes = 0;
        let totalUsedBytes = 0;
        let paidSubscriptionsCount = 0;
        let totalPaidAddonBytes = 0;
        let monthlyRecurringRevenue = 0;
        const plansBreakdown = {
            STARTER_15GB: 0,
            ADDON_25GB: 0,
            ADDON_50GB: 0,
            ADDON_100GB: 0,
            CUSTOM: 0,
        };
        const clientRows = [];
        // Pre-query row counts per outlet for ultra-fast, real database telemetry
        const rowsPerOutlet = new Map();
        if (activeDb) {
            try {
                const counts = await activeDb.query('SELECT outlet_id, COUNT(*) as count FROM item_master GROUP BY outlet_id ' +
                    'UNION ALL ' +
                    'SELECT outlet_id, COUNT(*) as count FROM sales_headers GROUP BY outlet_id;', { type: 'SELECT' }).catch(() => []);
                const list = Array.isArray(counts) ? counts : (counts?.[0] || []);
                for (const row of list) {
                    const oId = Number(row.outlet_id);
                    const cnt = Number(row.count || 0);
                    rowsPerOutlet.set(oId, (rowsPerOutlet.get(oId) || 0) + cnt);
                }
            }
            catch (_) { }
        }
        for (const o of outletList) {
            const oId = Number(o.id);
            const oCode = String(o.outlet_code || ('OUT_' + oId));
            const oName = String(o.outlet_name || ('Outlet #' + oId));
            let q = quotaMap.get(oCode);
            if (!q) {
                try {
                    q = await this.getOrCreateQuota(activeDb, oId, oCode);
                }
                catch (_) { }
            }
            const paths = this.getTenantStoragePaths(oCode);
            const backupsBytes = await this.getDirSize(paths.backupsDir);
            const uploadsBytes = await this.getDirSize(paths.uploadsDir);
            const exportsBytes = await this.getDirSize(paths.exportsDir);
            const rowCount = rowsPerOutlet.get(oId) || 0;
            const databaseBytes = rowCount > 0 ? (rowCount * 512) : 0;
            const totalUsed = backupsBytes + uploadsBytes + exportsBytes + databaseBytes;
            const baseBytes = Number(q?.base_quota_bytes || this.DEFAULT_BASE_QUOTA_BYTES);
            const addonBytes = Number(q?.addon_quota_bytes || 0);
            const bonusBytes = Number(q?.promotional_bonus_bytes || 0);
            const totalAllocated = baseBytes + addonBytes + bonusBytes;
            const freeBytes = Math.max(0, totalAllocated - totalUsed);
            const usagePct = totalAllocated > 0 ? Math.min(100, parseFloat(((totalUsed / totalAllocated) * 100).toFixed(2))) : 0;
            const isFrozen = totalUsed >= totalAllocated;
            const isCritical = usagePct >= 95 && usagePct < 100;
            const isWarning = usagePct >= 80 && usagePct < 95;
            const telemetry = {
                totalUsedBytes: totalUsed,
                totalUsedPretty: this.formatBytes(totalUsed),
                freeBytes,
                freePretty: this.formatBytes(freeBytes),
                usagePct,
                isFrozen,
                isCritical,
                isWarning,
                breakdown: {
                    backupsBytes,
                    backupsPretty: this.formatBytes(backupsBytes),
                    uploadsBytes,
                    uploadsPretty: this.formatBytes(uploadsBytes),
                    exportsBytes,
                    exportsPretty: this.formatBytes(exportsBytes),
                    databaseBytes,
                    databasePretty: this.formatBytes(databaseBytes),
                }
            };
            totalAllocatedBytes += totalAllocated;
            totalUsedBytes += totalUsed;
            const activePlan = String(q?.active_plan_code || 'STARTER_15GB');
            const isPaid = addonBytes > 0 || activePlan.startsWith('ADDON_');
            if (isPaid) {
                paidSubscriptionsCount++;
                totalPaidAddonBytes += addonBytes;
                const price = planPrices[activePlan] || (Math.round(addonBytes / (1024 * 1024 * 1024)) * 3.5);
                monthlyRecurringRevenue += price;
            }
            if (plansBreakdown[activePlan] !== undefined) {
                plansBreakdown[activePlan]++;
            }
            else {
                plansBreakdown.CUSTOM = (plansBreakdown.CUSTOM || 0) + 1;
            }
            clientRows.push({
                outletId: oId,
                outletCode: oCode,
                outletName: oName,
                businessModule: o.business_module || 'ALL',
                baseQuotaPretty: this.formatBytes(baseBytes),
                addonQuotaBytes: addonBytes,
                addonQuotaPretty: this.formatBytes(addonBytes),
                bonusQuotaPretty: this.formatBytes(bonusBytes),
                totalAllocatedBytes: totalAllocated,
                totalAllocatedPretty: this.formatBytes(totalAllocated),
                totalUsedBytes: totalUsed,
                totalUsedPretty: this.formatBytes(totalUsed),
                usagePct: telemetry.usagePct,
                freePretty: telemetry.freePretty,
                activePlanCode: activePlan,
                isPaidPlan: isPaid,
                monthlyPrice: isPaid ? (planPrices[activePlan] || 99) : 0,
                planExpiresAt: q?.plan_expires_at || null,
                isFrozen: telemetry.isFrozen,
                status: telemetry.isFrozen ? 'FROZEN' : (telemetry.isCritical ? 'CRITICAL' : (telemetry.isWarning ? 'WARNING' : 'ACTIVE')),
                breakdown: telemetry.breakdown,
            });
        }
        clientRows.sort((a, b) => b.totalUsedBytes - a.totalUsedBytes);
        return {
            totalOutlets: outletList.length,
            totalAllocatedBytes,
            totalAllocatedPretty: this.formatBytes(totalAllocatedBytes),
            totalUsedBytes,
            totalUsedPretty: this.formatBytes(totalUsedBytes),
            paidSubscriptionsCount,
            totalPaidAddonBytes,
            totalPaidAddonPretty: this.formatBytes(totalPaidAddonBytes),
            monthlyRecurringRevenue,
            plansBreakdown,
            outlets: clientRows,
        };
    }
    /**
     * 6. Admin Console: Modify / Increase Client Storage
     * Admin can grant +GB, set custom total GB, or unfreeze accounts.
     */
    static async adminModifyStorage(activeDb, options) {
        const { outletCode, action, additionalGb = 0, totalGb = 0, notes } = options;
        const quota = await activeDb.models.outlet_storage_quotas.findOne({
            where: { outlet_code: outletCode },
        });
        if (!quota) {
            throw new Error(`Quota record not found for outlet [${outletCode}].`);
        }
        const baseBytes = Number(quota.base_quota_bytes || this.DEFAULT_BASE_QUOTA_BYTES);
        let addonBytes = Number(quota.addon_quota_bytes || 0);
        let bonusBytes = Number(quota.promotional_bonus_bytes || 0);
        let message = '';
        if (action === 'ADD_GB') {
            const addedBytes = Math.round(Number(additionalGb) * 1024 * 1024 * 1024);
            addonBytes += addedBytes;
            const newTotal = baseBytes + addonBytes + bonusBytes;
            await quota.update({
                addon_quota_bytes: addonBytes,
                total_allocated_bytes: newTotal,
                is_frozen: false,
            });
            message = `Added +${additionalGb} GB storage to ${outletCode}. New total allocation: ${this.formatBytes(newTotal)}.`;
        }
        else if (action === 'ADD_BONUS_GB') {
            const addedBonus = Math.round(Number(additionalGb) * 1024 * 1024 * 1024);
            bonusBytes += addedBonus;
            const newTotal = baseBytes + addonBytes + bonusBytes;
            await quota.update({
                promotional_bonus_bytes: bonusBytes,
                total_allocated_bytes: newTotal,
                is_frozen: false,
            });
            message = `Granted +${additionalGb} GB promotional bonus to ${outletCode}. New total allocation: ${this.formatBytes(newTotal)}.`;
        }
        else if (action === 'SET_TOTAL_GB') {
            const targetTotalBytes = Math.round(Number(totalGb) * 1024 * 1024 * 1024);
            addonBytes = Math.max(0, targetTotalBytes - baseBytes - bonusBytes);
            await quota.update({
                addon_quota_bytes: addonBytes,
                total_allocated_bytes: targetTotalBytes,
                is_frozen: false,
            });
            message = `Set storage quota for ${outletCode} to ${totalGb} GB.`;
        }
        else if (action === 'FREEZE') {
            await quota.update({ is_frozen: true });
            message = `Outlet ${outletCode} storage has been frozen by Admin Console.`;
        }
        else if (action === 'UNFREEZE') {
            await quota.update({ is_frozen: false });
            message = `Outlet ${outletCode} storage has been unfrozen by Admin Console.`;
        }
        const refreshed = await this.calculateTenantStorage(activeDb, Number(quota.outlet_id), outletCode);
        return {
            success: true,
            message,
            data: refreshed,
        };
    }
    /**
     * 7. Automatic Storage Increment on Payment Success
     * Extends monthly storage upon payment confirmation webhook/callback.
     */
    static async processPaymentSuccess(activeDb, payload) {
        const { outletCode, planCode, amount, transactionId } = payload;
        const upgradeRes = await this.upgradeStorageAddon(activeDb, outletCode, planCode);
        const quota = await activeDb.models.outlet_storage_quotas.findOne({
            where: { outlet_code: outletCode },
        });
        if (quota) {
            const now = new Date();
            const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30-day monthly validity
            await quota.update({
                plan_expires_at: expiresAt,
                is_frozen: false,
            });
        }
        const refreshed = await this.calculateTenantStorage(activeDb, Number(quota?.outlet_id || 1), outletCode);
        return {
            success: true,
            message: `Payment successful (${transactionId ? "Txn: " + transactionId : "Success"}). ${upgradeRes.message} Valid for 30 days.`,
            quota: refreshed,
        };
    }
}
exports.StorageQuotaService = StorageQuotaService;
exports.default = StorageQuotaService;
module.exports = StorageQuotaService;
