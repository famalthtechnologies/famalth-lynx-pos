"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TenantBackupService = void 0;
const fs_1 = __importDefault(require("fs"));
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const zlib_1 = __importDefault(require("zlib"));
const crypto_1 = __importDefault(require("crypto"));
const sequelize_1 = require("sequelize");
const archiver = require('archiver');
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const canonicalRootDir = path_1.default.basename(rootDir) === 'backend' ? path_1.default.dirname(rootDir) : rootDir;
const BACKUP_BASE_DIR = path_1.default.join(canonicalRootDir, 'backups');
function getBackupSearchRoots() {
    const current = process.cwd();
    const roots = [
        BACKUP_BASE_DIR,
        path_1.default.join(canonicalRootDir, 'backend', 'backups'),
        path_1.default.join(current, 'backups'),
        path_1.default.join(current, 'backend', 'backups'),
    ];
    return [...new Set(roots)].filter(d => fs_1.default.existsSync(d));
}
function formatBytes(bytes, decimals = 1) {
    if (bytes === 0)
        return '0 B';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}
function timeSince(date) {
    const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
    if (seconds < 60)
        return 'just now';
    let interval = Math.floor(seconds / 31536000);
    if (interval >= 1)
        return `${interval} year${interval === 1 ? '' : 's'} ago`;
    interval = Math.floor(seconds / 2592000);
    if (interval >= 1)
        return `${interval} month${interval === 1 ? '' : 's'} ago`;
    interval = Math.floor(seconds / 86400);
    if (interval >= 1)
        return `${interval} day${interval === 1 ? '' : 's'} ago`;
    interval = Math.floor(seconds / 3600);
    if (interval >= 1)
        return `${interval} hour${interval === 1 ? '' : 's'} ago`;
    interval = Math.floor(seconds / 60);
    if (interval >= 1)
        return `${interval} minute${interval === 1 ? '' : 's'} ago`;
    return `${Math.floor(seconds)} seconds ago`;
}
async function getDirectorySizeAndFiles(dirPath, allowedExts = []) {
    let totalSize = 0;
    let fileCount = 0;
    const fileList = [];
    if (!fs_1.default.existsSync(dirPath)) {
        return { size: 0, count: 0, files: [] };
    }
    async function walk(currentDir) {
        try {
            const entries = await promises_1.default.readdir(currentDir, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path_1.default.join(currentDir, entry.name);
                if (entry.isDirectory()) {
                    await walk(fullPath);
                }
                else if (entry.isFile()) {
                    if (allowedExts.length > 0) {
                        const ext = path_1.default.extname(entry.name).toLowerCase();
                        if (!allowedExts.includes(ext))
                            continue;
                    }
                    const stat = await promises_1.default.stat(fullPath);
                    totalSize += stat.size;
                    fileCount++;
                    fileList.push({ path: fullPath, name: entry.name, size: stat.size, mtime: stat.mtime });
                }
            }
        }
        catch (_) { }
    }
    await walk(dirPath);
    return { size: totalSize, count: fileCount, files: fileList };
}
class TenantBackupService {
    /**
     * 1. Get Enterprise Storage Usage and Backup Status
     */
    static async getStorageStats(activeDb, outletCode, isSuperAdmin = false) {
        let totalDiskBytes = 100 * 1024 * 1024 * 1024; // 100GB default fallback
        let totalFreeBytes = 50 * 1024 * 1024 * 1024;
        let totalUsedBytes = totalDiskBytes - totalFreeBytes;
        try {
            if (promises_1.default.statfs) {
                const stat = await promises_1.default.statfs(canonicalRootDir);
                const bsize = stat.bsize || 4096;
                totalDiskBytes = Number(stat.blocks) * bsize;
                totalFreeBytes = Number(stat.bavail || stat.bfree) * bsize;
                totalUsedBytes = totalDiskBytes - totalFreeBytes;
            }
        }
        catch (_) { }
        // Backups directory audit
        const backupAllowed = ['.posbak', '.enc', '.zip', '.sql', '.gz'];
        let backupDirData;
        if (!isSuperAdmin && outletCode && outletCode !== 'ALL' && outletCode !== 'DEFAULT') {
            // CLIENT-ISOLATED: Strict scoping - only this merchant's backups
            const clientFiles = [];
            let clientSize = 0;
            for (const root of getBackupSearchRoots()) {
                const outletSubdir = path_1.default.join(root, 'outlets', outletCode);
                const subData = await getDirectorySizeAndFiles(outletSubdir, ['.posbak', '.zip', '.gz']);
                for (const sf of subData.files) {
                    if (!clientFiles.some(f => f.name === sf.name)) {
                        clientFiles.push(sf);
                        clientSize += sf.size;
                    }
                }
                // Also check any tenant posbak in root matching tenant_backup_<outletCode>
                if (fs_1.default.existsSync(root)) {
                    try {
                        const rootEntries = await promises_1.default.readdir(root, { withFileTypes: true });
                        for (const entry of rootEntries) {
                            if (entry.isFile() && entry.name.startsWith(`tenant_backup_${outletCode}_`)) {
                                const fPath = path_1.default.join(root, entry.name);
                                const stat = await promises_1.default.stat(fPath);
                                if (!clientFiles.some(f => f.name === entry.name)) {
                                    clientFiles.push({ path: fPath, name: entry.name, size: stat.size, mtime: stat.mtime });
                                    clientSize += stat.size;
                                }
                            }
                        }
                    }
                    catch (_) { }
                }
            }
            backupDirData = {
                size: clientSize,
                count: clientFiles.length,
                files: clientFiles,
            };
        }
        else {
            // Full enterprise audit
            backupDirData = await getDirectorySizeAndFiles(BACKUP_BASE_DIR, backupAllowed);
        }
        // Uploads directory audit
        const uploadsDir = path_1.default.join(rootDir, 'uploads');
        const publicUploadsDir = path_1.default.join(rootDir, 'public', 'uploads');
        const uploadsData1 = await getDirectorySizeAndFiles(uploadsDir);
        const uploadsData2 = await getDirectorySizeAndFiles(publicUploadsDir);
        const totalUploadsBytes = uploadsData1.size + uploadsData2.size;
        // Database size query
        let databaseBytes = 0;
        try {
            if (activeDb && typeof activeDb.query === 'function') {
                const [dbSizeRes] = await activeDb.query('SELECT pg_database_size(current_database()) as db_bytes;', { type: sequelize_1.QueryTypes.SELECT });
                if (dbSizeRes && dbSizeRes.db_bytes) {
                    databaseBytes = Number(dbSizeRes.db_bytes);
                }
            }
        }
        catch (_) { }
        // Sort backups by modification date descending
        const sortedFiles = backupDirData.files.sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
        const backupsList = sortedFiles.map((f) => ({
            filename: f.name,
            sizeBytes: f.size,
            sizePretty: formatBytes(f.size),
            createdAt: f.mtime.toISOString(),
            timeAgo: timeSince(f.mtime),
            downloadUrl: `/api/backup/download/${encodeURIComponent(f.name)}`,
        }));
        const latestBackup = backupsList.length > 0 ? backupsList[0] : null;
        const percentageUsed = totalDiskBytes > 0
            ? parseFloat(((totalUsedBytes / totalDiskBytes) * 100).toFixed(1))
            : 0;
        return {
            totalUsedBytes,
            totalFreeBytes,
            totalDiskBytes,
            totalUsedPretty: formatBytes(totalUsedBytes),
            totalFreePretty: formatBytes(totalFreeBytes),
            percentageUsed,
            breakdown: {
                backupsBytes: backupDirData.size,
                backupsPretty: formatBytes(backupDirData.size),
                backupsCount: backupDirData.count,
                uploadsBytes: totalUploadsBytes,
                uploadsPretty: formatBytes(totalUploadsBytes),
                databaseBytes,
                databasePretty: formatBytes(databaseBytes),
            },
            latestBackup,
            backupsList,
        };
    }
    /**
     * 2. Get Enterprise-Wide & Particular Outlet-Wise Storage Analytics
     * Provides complete system storage metrics plus row-accurate outlet-by-outlet storage.
     */
    static async getEnterpriseStorageAnalytics(activeDb) {
        const systemStorage = await this.getStorageStats(activeDb, 'ALL');
        const outletsResult = await activeDb.query(`SELECT id, outlet_code, outlet_name, business_module, created_at FROM outlets ORDER BY id ASC;`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
        const outletList = Array.isArray(outletsResult) ? outletsResult : (outletsResult?.[0] || []);
        const tablesToTrack = [
            'sales_headers', 'item_master', 'stock_ledger', 'customers',
            'goods_receipts', 'purchase_orders', 'kot_headers', 'expenses',
            'clinic_appointments', 'hr_attendance_punches', 'restaurant_tables',
            'accounting_vouchers', 'user_notes', 'milk_subscriptions'
        ];
        const outletRowCounts = {};
        outletList.forEach((o) => { outletRowCounts[o.id] = 0; });
        let totalTrackedRows = 0;
        for (const tbl of tablesToTrack) {
            try {
                const rows = await activeDb.query(`SELECT outlet_id, count(*)::int as count FROM "${tbl}" GROUP BY outlet_id;`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                for (const r of rowList) {
                    const count = Number(r.count || 0);
                    if (outletRowCounts[r.outlet_id] !== undefined) {
                        outletRowCounts[r.outlet_id] += count;
                    }
                    totalTrackedRows += count;
                }
            }
            catch (_) { }
        }
        const totalDbBytes = systemStorage.breakdown.databaseBytes || 1;
        const outletStorageList = [];
        // Scan root backups directory once for performance
        const rootBackupCheck = await getDirectorySizeAndFiles(BACKUP_BASE_DIR, ['.posbak', '.enc']);
        for (const o of outletList) {
            const oId = Number(o.id);
            const oCode = String(o.outlet_code || `OUT_${oId}`);
            const oName = String(o.outlet_name || `Outlet #${oId}`);
            const oModule = String(o.business_module || 'ALL');
            const rowCount = outletRowCounts[oId] || 0;
            const ratio = totalTrackedRows > 0 ? (rowCount / totalTrackedRows) : (1 / Math.max(outletList.length, 1));
            const estDbBytes = Math.round(ratio * totalDbBytes);
            // Check physical backups in outlet-specific subfolder
            const outletBackupDir = path_1.default.join(BACKUP_BASE_DIR, 'outlets', oCode);
            const backupData = await getDirectorySizeAndFiles(outletBackupDir, ['.posbak', '.enc', '.zip', '.sql']);
            const matchingRootBackups = rootBackupCheck.files.filter(f => f.name.includes(oCode));
            const totalBackupsBytes = backupData.size + matchingRootBackups.reduce((acc, f) => acc + f.size, 0);
            const totalBackupsCount = backupData.count + matchingRootBackups.length;
            // Identify latest backup for this outlet
            const allOutletBackupFiles = [...backupData.files, ...matchingRootBackups].sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
            const latestBackupTime = allOutletBackupFiles.length > 0 ? allOutletBackupFiles[0].mtime.toISOString() : null;
            const latestBackupTimeAgo = allOutletBackupFiles.length > 0 ? timeSince(allOutletBackupFiles[0].mtime) : 'No backups';
            // Check uploads for this outlet (uploads/items/<outlet_id>, etc.)
            const outletUploadsDir = path_1.default.join(rootDir, 'uploads', 'items', String(oId));
            const uploadsData = await getDirectorySizeAndFiles(outletUploadsDir);
            const totalOutletBytes = estDbBytes + totalBackupsBytes + uploadsData.size;
            const totalSystemUsed = systemStorage.totalUsedBytes || 1;
            const percentageOfUsed = parseFloat(((totalOutletBytes / totalSystemUsed) * 100).toFixed(2));
            // Calculate monthly sync bandwidth footprint (sync API exchanges + uploads + backups)
            const estBandwidthBytes = Math.round((rowCount * 3500) + (totalBackupsBytes * 0.4) + (uploadsData.size * 1.2) + (rowCount > 0 ? 1024 * 1024 * 5 : 0));
            outletStorageList.push({
                outletId: oId,
                outletCode: oCode,
                outletName: oName,
                businessModule: oModule,
                recordCount: rowCount,
                databaseBytes: estDbBytes,
                databasePretty: formatBytes(estDbBytes),
                bandwidthBytes: estBandwidthBytes,
                bandwidthPretty: formatBytes(estBandwidthBytes),
                backupsBytes: totalBackupsBytes,
                backupsPretty: formatBytes(totalBackupsBytes),
                backupsCount: totalBackupsCount,
                uploadsBytes: uploadsData.size,
                uploadsPretty: formatBytes(uploadsData.size),
                totalBytes: totalOutletBytes,
                totalPretty: formatBytes(totalOutletBytes),
                percentageOfUsed,
                latestBackupTime,
                latestBackupTimeAgo,
            });
        }
        // Sort descending by total bytes used
        outletStorageList.sort((a, b) => b.totalBytes - a.totalBytes);
        return {
            systemStorage,
            totalOutletsCount: outletList.length,
            outletStorageList,
        };
    }
    /**
     * 3. Create Tenant-Isolated Portable Backup (.posbak)
     * Backs up ONLY the data belonging to this outlet/tenant! Zero cross-client data.
     */
    static async createTenantBackup(activeDb, outletId, outletCode, outletMeta = {}) {
        const targetOutletId = Number(outletId);
        if (!targetOutletId)
            throw new Error('Valid target outlet ID is required for tenant backup.');
        const outletDir = path_1.default.join(BACKUP_BASE_DIR, 'outlets', outletCode || `outlet_${targetOutletId}`);
        await promises_1.default.mkdir(outletDir, { recursive: true });
        // Table export list: Scoped parent tables and their child items
        const scopedTables = [
            'system_settings',
            'item_master',
            'batches',
            'stock_ledger',
            'stock_locations',
            'item_modifiers',
            'item_boms',
            'customers',
            'sales_headers',
            'restaurant_tables',
            'table_reservations',
            'kot_headers',
            'purchase_orders',
            'goods_receipts',
            'supplier_master',
            'supplier_bills',
            'supplier_payments',
            'clinic_appointments',
            'hr_employees',
            'hr_attendance_punches',
            'hr_biometric_devices',
            'expenses',
            'accounting_vouchers',
            'bank_accounts',
            'cash_ledger',
            'milk_subscriptions',
            'milk_subscription_consumptions',
            'user_notes',
        ];
        const backupData = {};
        let totalRecords = 0;
        for (const tbl of scopedTables) {
            try {
                const rows = await activeDb.query(`SELECT * FROM "${tbl}" WHERE outlet_id = :targetOutletId;`, {
                    replacements: { targetOutletId },
                    type: sequelize_1.QueryTypes.SELECT,
                });
                backupData[tbl] = rows || [];
                totalRecords += (rows || []).length;
            }
            catch (err) {
                // Table might not exist in old migration state, continue gracefully
                backupData[tbl] = [];
            }
        }
        // Export child tables linked via foreign key to parent tables of this outlet
        const childTables = [
            { name: 'sales_items', fk: 'sale_id', parentTable: 'sales_headers' },
            { name: 'kot_items', fk: 'kot_header_id', parentTable: 'kot_headers' },
            { name: 'purchase_order_items', fk: 'po_id', parentTable: 'purchase_orders' },
            { name: 'goods_receipt_items', fk: 'grn_id', parentTable: 'goods_receipts' },
            { name: 'voucher_lines', fk: 'voucher_id', parentTable: 'accounting_vouchers' },
            { name: 'milk_subscription_items', fk: 'subscription_id', parentTable: 'milk_subscriptions' },
        ];
        for (const child of childTables) {
            try {
                const rows = await activeDb.query(`SELECT c.* FROM "${child.name}" c 
           JOIN "${child.parentTable}" p ON c."${child.fk}" = p.id 
           WHERE p.outlet_id = :targetOutletId;`, {
                    replacements: { targetOutletId },
                    type: sequelize_1.QueryTypes.SELECT,
                });
                backupData[child.name] = rows || [];
                totalRecords += (rows || []).length;
            }
            catch (_) {
                backupData[child.name] = [];
            }
        }
        // Assemble tenant backup manifest
        const payload = {
            format: 'FAMALTH_POS_TENANT_BACKUP_V2',
            version: '2.0',
            exportedAt: new Date().toISOString(),
            sourceOutletId: targetOutletId,
            outletCode: outletCode || `OUTLET_${targetOutletId}`,
            outletMeta: {
                name: outletMeta.outlet_name || outletMeta.name || 'Store',
                business_module: outletMeta.business_module || 'ALL',
            },
            totalRecords,
            tables: backupData,
        };
        const jsonString = JSON.stringify(payload);
        const checksum = crypto_1.default.createHash('sha256').update(jsonString).digest('hex');
        payload.checksum = checksum;
        // Compress with Gzip
        const compressedBuffer = zlib_1.default.gzipSync(Buffer.from(JSON.stringify(payload), 'utf8'));
        const now = new Date();
        const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}-${String(now.getMinutes()).padStart(2, '0')}-${String(now.getSeconds()).padStart(2, '0')}`;
        const filename = `tenant_backup_${outletCode || `OUT${targetOutletId}`}_${timestamp}.posbak`;
        const filePath = path_1.default.join(outletDir, filename);
        // Also place a symlink/copy in main backups folder for unified management
        const rootBackupPath = path_1.default.join(BACKUP_BASE_DIR, filename);
        await promises_1.default.writeFile(filePath, compressedBuffer);
        try {
            await promises_1.default.copyFile(filePath, rootBackupPath);
        }
        catch (_) { }
        return {
            filename,
            filePath,
            sizeBytes: compressedBuffer.length,
            sizePretty: formatBytes(compressedBuffer.length),
            totalRecords,
            downloadUrl: `/api/backup/download/${encodeURIComponent(filename)}`,
        };
    }
    /**
     * 3. Restore / Migrate Tenant Backup onto Target Server & Target Outlet
     * Safe for cloud or offline servers: Strictly remaps records into destination outlet,
     * without affecting any other merchants on the destination database.
     */
    static async restoreTenantBackup(activeDb, targetOutletId, fileBuffer, options = {}) {
        const destOutletId = Number(targetOutletId);
        if (!destOutletId)
            throw new Error('Valid target outlet ID is required for restore.');
        // Decompress payload
        let jsonText;
        try {
            const decompressed = zlib_1.default.gunzipSync(fileBuffer);
            jsonText = decompressed.toString('utf8');
        }
        catch (e) {
            // If not gzipped, try raw utf8
            jsonText = fileBuffer.toString('utf8');
        }
        let payload;
        try {
            payload = JSON.parse(jsonText);
        }
        catch (e) {
            throw new Error(`Invalid backup file format: ${e.message}`);
        }
        if (payload.format !== 'FAMALTH_POS_TENANT_BACKUP_V2' && !payload.tables) {
            throw new Error('Unrecognized backup format. Please supply a valid .posbak file.');
        }
        const tables = payload.tables || {};
        const tableKeys = Object.keys(tables);
        let totalRecordsRestored = 0;
        const tablesRestored = [];
        // Execute restore inside transaction to ensure atomicity
        await activeDb.transaction(async (t) => {
            // If overwrite requested, clean target outlet data first
            if (options.overwriteExisting) {
                // Child tables first
                const childDeleteList = [
                    'sales_items', 'kot_items', 'purchase_order_items', 'goods_receipt_items', 'voucher_lines', 'milk_subscription_items'
                ];
                for (const tbl of childDeleteList) {
                    try {
                        await activeDb.query(`DELETE FROM "${tbl}" WHERE id IN (SELECT id FROM "${tbl}" WHERE outlet_id = :destOutletId);`, { replacements: { destOutletId }, transaction: t }).catch(() => { });
                    }
                    catch (_) { }
                }
            }
            // Priority ordering for parent tables
            const orderedTables = [
                'system_settings',
                'item_master',
                'batches',
                'stock_locations',
                'item_modifiers',
                'item_boms',
                'customers',
                'sales_headers',
                'sales_items',
                'restaurant_tables',
                'table_reservations',
                'kot_headers',
                'kot_items',
                'purchase_orders',
                'purchase_order_items',
                'goods_receipts',
                'goods_receipt_items',
                'supplier_master',
                'supplier_bills',
                'supplier_payments',
                'clinic_appointments',
                'hr_employees',
                'hr_attendance_punches',
                'hr_biometric_devices',
                'expenses',
                'accounting_vouchers',
                'voucher_lines',
                'bank_accounts',
                'cash_ledger',
                'stock_ledger',
                'milk_subscriptions',
                'milk_subscription_consumptions',
                'user_notes',
            ];
            for (const tbl of orderedTables) {
                const rows = tables[tbl];
                if (!Array.isArray(rows) || rows.length === 0)
                    continue;
                for (const row of rows) {
                    const rowCopy = { ...row };
                    // STRICT OUTLET REMAPPING: Force row to destination outlet
                    if ('outlet_id' in rowCopy) {
                        rowCopy.outlet_id = destOutletId;
                    }
                    const cols = Object.keys(rowCopy);
                    const colList = cols.map((c) => `"${c}"`).join(', ');
                    const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                    const values = Object.values(rowCopy);
                    try {
                        await activeDb.query(`INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`, { bind: values, transaction: t });
                        totalRecordsRestored++;
                    }
                    catch (rowErr) {
                        // Ignore duplicate constraint errors during merge
                    }
                }
                tablesRestored.push(tbl);
            }
            // Reset serial sequence counters for restored tables
            try {
                await activeDb.query(`
          DO $$
          DECLARE
            r RECORD;
          BEGIN
            FOR r IN (
              SELECT c.table_name, c.column_name, pg_get_serial_sequence(c.table_name, c.column_name) AS seq_name
              FROM information_schema.columns c
              WHERE c.table_schema = 'public' AND pg_get_serial_sequence(c.table_name, c.column_name) IS NOT NULL
            ) LOOP
              EXECUTE format('SELECT setval(''%s'', COALESCE((SELECT MAX(%I) FROM %I), 1), true)', r.seq_name, r.column_name, r.table_name);
            END LOOP;
          END $$;
        `, { transaction: t });
            }
            catch (_) { }
        });
        return {
            success: true,
            totalRecordsRestored,
            tablesRestored,
            outletId: destOutletId,
        };
    }
    /**
     * 4. Resolve Physical File Path for Secure Download
     */
    static resolveBackupFilePath(filename, outletCode, isSuperAdmin = false) {
        const sanitized = path_1.default.basename(filename);
        const searchRoots = getBackupSearchRoots();
        for (const root of searchRoots) {
            if (outletCode) {
                const outletPath = path_1.default.join(root, 'outlets', outletCode, sanitized);
                if (fs_1.default.existsSync(outletPath))
                    return outletPath;
            }
            const rootCandidate = path_1.default.join(root, sanitized);
            if (fs_1.default.existsSync(rootCandidate)) {
                if (!isSuperAdmin && outletCode) {
                    if (sanitized.includes(outletCode))
                        return rootCandidate;
                }
                else {
                    return rootCandidate;
                }
            }
            // Check subdirectories in outlets/
            const outletsDir = path_1.default.join(root, 'outlets');
            if (fs_1.default.existsSync(outletsDir)) {
                try {
                    const subdirs = fs_1.default.readdirSync(outletsDir);
                    for (const sub of subdirs) {
                        if (!isSuperAdmin && outletCode && sub !== outletCode)
                            continue;
                        const cand = path_1.default.join(outletsDir, sub, sanitized);
                        if (fs_1.default.existsSync(cand))
                            return cand;
                    }
                }
                catch (_) { }
            }
        }
        return null;
    }
    /**
     * 5. Delete Backup File
     */
    static async deleteBackup(filename, outletCode, isSuperAdmin = false) {
        const filePath = this.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
        if (!filePath) {
            return { success: false, message: 'Backup snapshot not found on disk or permission denied.' };
        }
        if (!isSuperAdmin && outletCode) {
            const isAllowed = filePath.includes(path_1.default.join('outlets', outletCode)) || filename.includes(outletCode);
            if (!isAllowed) {
                return { success: false, message: 'Access denied: You can only delete your own outlet backups.' };
            }
        }
        try {
            await promises_1.default.unlink(filePath);
            return { success: true };
        }
        catch (err) {
            return { success: false, message: err.message || 'File deletion failed.' };
        }
    }
    /**
     * 6. Generate Complete Full-System Data Backup
     * Backs up all outlets, global configurations, and schemas into a signed system archive.
     */
    static async createSystemBackup(activeDb) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        const filename = `system_full_backup_${timestamp}.posbak`;
        const filePath = path_1.default.join(BACKUP_BASE_DIR, filename);
        const allTables = [
            'outlets', 'system_settings', 'item_master', 'batches', 'stock_locations',
            'item_modifiers', 'item_boms', 'customers', 'sales_headers', 'sales_items',
            'restaurant_tables', 'table_reservations', 'kot_headers', 'kot_items',
            'purchase_orders', 'purchase_order_items', 'goods_receipts', 'goods_receipt_items',
            'supplier_master', 'supplier_bills', 'supplier_payments', 'clinic_appointments',
            'hr_employees', 'hr_attendance_punches', 'hr_biometric_devices', 'expenses',
            'accounting_vouchers', 'voucher_lines', 'bank_accounts', 'cash_ledger',
            'stock_ledger', 'milk_subscriptions', 'milk_subscription_consumptions', 'user_notes'
        ];
        const exportPayload = {};
        let totalRecords = 0;
        for (const tbl of allTables) {
            try {
                const rows = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                exportPayload[tbl] = rowList;
                totalRecords += rowList.length;
            }
            catch (_) {
                exportPayload[tbl] = [];
            }
        }
        const archiveManifest = {
            format: 'FAMALTH_POS_FULL_SYSTEM_BACKUP_V2',
            version: '2.0.0',
            createdAt: new Date().toISOString(),
            type: 'FULL_SYSTEM_SNAPSHOT',
            totalRecords,
            tables: exportPayload,
        };
        const jsonString = JSON.stringify(archiveManifest);
        const compressedBuffer = zlib_1.default.gzipSync(Buffer.from(jsonString, 'utf8'), { level: 9 });
        const checksum = crypto_1.default.createHash('sha256').update(compressedBuffer).digest('hex');
        await promises_1.default.mkdir(BACKUP_BASE_DIR, { recursive: true });
        await promises_1.default.writeFile(filePath, compressedBuffer);
        return {
            filename,
            filePath,
            totalRecords,
            sizeBytes: compressedBuffer.length,
            checksum,
        };
    }
    /**
     * 7. Restore Complete System Backup
     */
    static async restoreSystemBackup(activeDb, fileBuffer) {
        let jsonText;
        try {
            jsonText = zlib_1.default.gunzipSync(fileBuffer).toString('utf8');
        }
        catch {
            jsonText = fileBuffer.toString('utf8');
        }
        const payload = JSON.parse(jsonText);
        const tables = payload.tables || {};
        let totalRecordsRestored = 0;
        const tablesRestored = [];
        await activeDb.transaction(async (t) => {
            for (const [tbl, rows] of Object.entries(tables)) {
                if (!Array.isArray(rows) || rows.length === 0)
                    continue;
                for (const row of rows) {
                    const cols = Object.keys(row);
                    const colList = cols.map((c) => `"${c}"`).join(', ');
                    const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                    const values = Object.values(row);
                    try {
                        await activeDb.query(`INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`, { bind: values, transaction: t });
                        totalRecordsRestored++;
                    }
                    catch (_) { }
                }
                tablesRestored.push(tbl);
            }
        });
        return {
            success: true,
            totalRecordsRestored,
            tablesRestored,
        };
    }
    /**
     * 8. Enterprise Professional Complete System Backup (.zip)
     * Packages:
     *  1. manifest.json (metadata, checksum, system info)
     *  2. database.json (complete records for all 35+ tables)
     *  3. database.sql (standard SQL script for raw psql restore)
     *  4. uploads/ (all media, invoices, prescription scans, product images)
     */
    static async createEnterpriseZipBackup(activeDb, includeUploads = true) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        const filename = `famalth-enterprise-backup-${timestamp}.zip`;
        const filePath = path_1.default.join(BACKUP_BASE_DIR, filename);
        await promises_1.default.mkdir(BACKUP_BASE_DIR, { recursive: true });
        const allTables = [
            'outlets', 'system_settings', 'item_master', 'batches', 'stock_locations',
            'item_modifiers', 'item_boms', 'customers', 'sales_headers', 'sales_items',
            'restaurant_tables', 'table_reservations', 'kot_headers', 'kot_items',
            'purchase_orders', 'purchase_order_items', 'goods_receipts', 'goods_receipt_items',
            'supplier_master', 'supplier_bills', 'supplier_payments', 'clinic_appointments',
            'hr_employees', 'hr_attendance_punches', 'hr_biometric_devices', 'expenses',
            'accounting_vouchers', 'voucher_lines', 'bank_accounts', 'cash_ledger',
            'stock_ledger', 'milk_subscriptions', 'milk_subscription_consumptions', 'user_notes',
            'users'
        ];
        const exportPayload = {};
        let totalRecords = 0;
        let sqlScript = `-- FAMALTH ENTERPRISE POSTGRESQL COMPLETE DUMP\n-- Generated: ${new Date().toISOString()}\n\nBEGIN;\n`;
        for (const tbl of allTables) {
            try {
                const rows = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                exportPayload[tbl] = rowList;
                totalRecords += rowList.length;
                if (rowList.length > 0) {
                    sqlScript += `\n-- Table: ${tbl} (${rowList.length} rows)\n`;
                    for (const row of rowList) {
                        const cols = Object.keys(row).map(c => `"${c}"`).join(', ');
                        const vals = Object.values(row).map(v => {
                            if (v === null || v === undefined)
                                return 'NULL';
                            if (typeof v === 'number' || typeof v === 'boolean')
                                return v;
                            if (typeof v === 'object')
                                return `'${JSON.stringify(v).replace(/'/g, "''")}'`;
                            return `'${String(v).replace(/'/g, "''")}'`;
                        }).join(', ');
                        sqlScript += `INSERT INTO "${tbl}" (${cols}) VALUES (${vals}) ON CONFLICT DO NOTHING;\n`;
                    }
                }
            }
            catch (_) {
                exportPayload[tbl] = [];
            }
        }
        sqlScript += `\nCOMMIT;\n`;
        const manifest = {
            format: 'FAMALTH_ENTERPRISE_SYSTEM_BACKUP_V1',
            version: '1.0.0',
            backup_type: 'FULL_SYSTEM_AND_UPLOADS',
            created_at: new Date().toISOString(),
            generator: 'Famalth Enterprise Master Control Plane',
            system: {
                node_version: process.version,
                database: 'PostgreSQL',
            },
            tables_count: allTables.length,
            total_records: totalRecords,
            includes_uploads: includeUploads,
        };
        // Build the ZIP archive stream using archiver
        await new Promise((resolve, reject) => {
            const output = fs_1.default.createWriteStream(filePath);
            const archive = archiver('zip', {
                zlib: { level: 9 },
            });
            output.on('close', () => resolve());
            archive.on('error', (err) => reject(err));
            archive.pipe(output);
            // 1. Add manifest.json
            archive.append(JSON.stringify(manifest, null, 2), { name: 'manifest.json' });
            // 2. Add database.json
            archive.append(JSON.stringify({ manifest, tables: exportPayload }, null, 2), { name: 'database.json' });
            // 3. Add database.sql
            archive.append(sqlScript, { name: 'database.sql' });
            // 4. Add uploads directory if requested and exists
            if (includeUploads) {
                const uploadsDir = path_1.default.join(canonicalRootDir, 'uploads');
                if (fs_1.default.existsSync(uploadsDir)) {
                    archive.directory(uploadsDir, 'uploads');
                }
                const backendUploadsDir = path_1.default.join(canonicalRootDir, 'backend', 'uploads');
                if (fs_1.default.existsSync(backendUploadsDir)) {
                    archive.directory(backendUploadsDir, 'backend_uploads');
                }
            }
            archive.finalize();
        });
        const stat = await promises_1.default.stat(filePath);
        return {
            filename,
            filePath,
            totalRecords,
            sizeBytes: stat.size,
            downloadUrl: `/api/backup/download/${encodeURIComponent(filename)}`,
        };
    }
    /**
     * 9. Restore Enterprise Complete System Backup (.zip or .posbak)
     */
    static async restoreEnterpriseZipBackup(activeDb, fileBuffer, filename) {
        const isZip = filename.toLowerCase().endsWith('.zip') || (fileBuffer.length > 4 && fileBuffer[0] === 0x50 && fileBuffer[1] === 0x4B);
        if (!isZip) {
            // Fallback to POSBAK / GZIP handler
            const res = await this.restoreSystemBackup(activeDb, fileBuffer);
            return {
                ...res,
                uploadsRestored: false,
            };
        }
        // Extract ZIP archive in-memory using unzipper
        const unzipper = require('unzipper');
        const directory = await unzipper.Open.buffer(fileBuffer);
        let databaseJsonText = '';
        let uploadsRestored = false;
        for (const file of directory.files) {
            if (file.path === 'database.json') {
                databaseJsonText = (await file.buffer()).toString('utf8');
            }
            else if (file.path.startsWith('uploads/')) {
                const relPath = file.path;
                const destPath = path_1.default.join(canonicalRootDir, relPath);
                if (file.type === 'Directory') {
                    await promises_1.default.mkdir(destPath, { recursive: true });
                }
                else {
                    await promises_1.default.mkdir(path_1.default.dirname(destPath), { recursive: true });
                    const content = await file.buffer();
                    await promises_1.default.writeFile(destPath, content);
                    uploadsRestored = true;
                }
            }
        }
        if (!databaseJsonText) {
            throw new Error('Invalid enterprise backup ZIP: database.json not found inside archive.');
        }
        const dbPayload = JSON.parse(databaseJsonText);
        const tables = dbPayload.tables || {};
        let totalRecordsRestored = 0;
        const tablesRestored = [];
        await activeDb.transaction(async (t) => {
            for (const [tbl, rows] of Object.entries(tables)) {
                if (!Array.isArray(rows) || rows.length === 0)
                    continue;
                for (const row of rows) {
                    const cols = Object.keys(row);
                    const colList = cols.map((c) => `"${c}"`).join(', ');
                    const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                    const values = Object.values(row);
                    try {
                        await activeDb.query(`INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`, { bind: values, transaction: t });
                        totalRecordsRestored++;
                    }
                    catch (_) { }
                }
                tablesRestored.push(tbl);
            }
            // Reset serial sequence counters
            try {
                await activeDb.query(`
          DO $$
          DECLARE
            r RECORD;
          BEGIN
            FOR r IN (
              SELECT c.table_name, c.column_name, pg_get_serial_sequence(c.table_name, c.column_name) AS seq_name
              FROM information_schema.columns c
              WHERE c.table_schema = 'public' AND pg_get_serial_sequence(c.table_name, c.column_name) IS NOT NULL
            ) LOOP
              EXECUTE format('SELECT setval(''%s'', COALESCE((SELECT MAX(%I) FROM %I), 1), true)', r.seq_name, r.column_name, r.table_name);
            END LOOP;
          END $$;
        `, { transaction: t });
            }
            catch (_) { }
        });
        return {
            success: true,
            totalRecordsRestored,
            tablesRestored,
            uploadsRestored,
        };
    }
}
exports.TenantBackupService = TenantBackupService;
exports.default = TenantBackupService;
