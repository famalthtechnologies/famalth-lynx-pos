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
const postRestoreHealing_1 = require("../utils/postRestoreHealing");
const archiver = require('archiver');
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const canonicalRootDir = path_1.default.basename(rootDir) === 'backend' ? path_1.default.dirname(rootDir) : rootDir;
const BACKUP_BASE_DIR = path_1.default.join(canonicalRootDir, 'backups');
function getBackupSearchRoots() {
    const current = process.cwd();
    const roots = [
        path_1.default.join(canonicalRootDir, 'backend', 'storage'),
        path_1.default.join(canonicalRootDir, 'storage'),
        path_1.default.join(current, 'backend', 'storage'),
        path_1.default.join(current, 'storage'),
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
        const diskRoot = path_1.default.parse(canonicalRootDir).root || process.cwd();
        let totalDiskBytes = 0;
        let totalFreeBytes = 0;
        let totalUsedBytes = 0;
        try {
            if (promises_1.default.statfs) {
                const stat = await promises_1.default.statfs(diskRoot);
                const bsize = stat.bsize || 4096;
                totalDiskBytes = Number(stat.blocks) * bsize;
                totalFreeBytes = Number(stat.bavail || stat.bfree) * bsize;
                totalUsedBytes = totalDiskBytes - totalFreeBytes;
            }
        }
        catch (_) { }
        if (totalDiskBytes === 0) {
            try {
                const stat = await promises_1.default.statfs(canonicalRootDir);
                const bsize = stat.bsize || 4096;
                totalDiskBytes = Number(stat.blocks) * bsize;
                totalFreeBytes = Number(stat.bavail || stat.bfree) * bsize;
                totalUsedBytes = totalDiskBytes - totalFreeBytes;
            }
            catch (_) { }
        }
        // Backups directory audit
        const backupAllowed = ['.fambak', '.posbak', '.enc', '.zip', '.sql', '.gz'];
        let backupDirData;
        if (!isSuperAdmin && outletCode && outletCode !== 'ALL' && outletCode !== 'DEFAULT') {
            // CLIENT-ISOLATED: Strict scoping - only this merchant's backups
            const clientFiles = [];
            let clientSize = 0;
            for (const root of getBackupSearchRoots()) {
                const candidateSubdirs = [
                    path_1.default.join(root, 'outlets', outletCode, 'backups'),
                    path_1.default.join(root, 'outlets', outletCode),
                ];
                for (const outletSubdir of candidateSubdirs) {
                    if (fs_1.default.existsSync(outletSubdir)) {
                        const subData = await getDirectorySizeAndFiles(outletSubdir, ['.fambak', '.posbak', '.zip', '.gz']);
                        for (const sf of subData.files) {
                            if (!clientFiles.some(f => f.name === sf.name)) {
                                clientFiles.push(sf);
                                clientSize += sf.size;
                            }
                        }
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
        const rootBackupCheck = await getDirectorySizeAndFiles(BACKUP_BASE_DIR, ['.fambak', '.posbak', '.enc']);
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
            const backupData = await getDirectorySizeAndFiles(outletBackupDir, ['.fambak', '.posbak', '.enc', '.zip', '.sql']);
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
        const rawStorage = require('./storageQuota.service');
        const StorageQuotaService = rawStorage.default || rawStorage;
        const tenantPaths = StorageQuotaService.getTenantStoragePaths(outletCode || `OUT_${targetOutletId}`);
        const outletDir = tenantPaths.backupsDir;
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
        // Cache valid table columns and types from information_schema
        const colMap = new Map();
        try {
            const [tableCols] = await activeDb.query(`
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
      `);
            for (const c of tableCols) {
                if (!colMap.has(c.table_name))
                    colMap.set(c.table_name, new Map());
                colMap.get(c.table_name).set(c.column_name, c.data_type);
            }
        }
        catch (schemaErr) {
            console.warn('⚠️ Could not query information_schema for backup restore validation:', schemaErr.message);
        }
        // Execute restore inside transaction to ensure atomicity
        await activeDb.transaction(async (t) => {
            // If overwrite requested, clean target outlet data first
            if (options.overwriteExisting) {
                // Child tables first
                const childDeleteList = [
                    `DELETE FROM "sales_items" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)`,
                    `DELETE FROM "kot_items" WHERE kot_header_id IN (SELECT id FROM "kot_headers" WHERE outlet_id = :destOutletId)`,
                    `DELETE FROM "purchase_order_items" WHERE po_id IN (SELECT id FROM "purchase_orders" WHERE outlet_id = :destOutletId)`,
                    `DELETE FROM "goods_receipt_items" WHERE grn_id IN (SELECT id FROM "goods_receipts" WHERE outlet_id = :destOutletId)`,
                    `DELETE FROM "voucher_lines" WHERE voucher_id IN (SELECT id FROM "accounting_vouchers" WHERE outlet_id = :destOutletId)`,
                    `DELETE FROM "milk_subscription_items" WHERE subscription_id IN (SELECT id FROM "milk_subscriptions" WHERE outlet_id = :destOutletId)`
                ];
                for (const q of childDeleteList) {
                    try {
                        await activeDb.query(q, { replacements: { destOutletId }, transaction: t }).catch(() => { });
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
                const validColMap = colMap.get(tbl);
                if (colMap.size > 0 && !validColMap)
                    continue;
                for (const row of rows) {
                    const rowCopy = { ...row };
                    // STRICT OUTLET REMAPPING: Force row to destination outlet
                    if ('outlet_id' in rowCopy) {
                        rowCopy.outlet_id = destOutletId;
                    }
                    // Filter row properties to only columns that physically exist in the database table
                    const cols = Object.keys(rowCopy).filter((c) => !validColMap || validColMap.has(c));
                    if (cols.length === 0)
                        continue;
                    const colList = cols.map((c) => `"${c}"`).join(', ');
                    const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                    const values = cols.map((c) => {
                        const val = rowCopy[c];
                        const dtype = validColMap ? validColMap.get(c) : null;
                        if (val !== null && typeof val === 'object' && !(val instanceof Date) && !Buffer.isBuffer(val)) {
                            return JSON.stringify(val);
                        }
                        if (dtype === 'json' || dtype === 'jsonb') {
                            if (typeof val === 'string')
                                return val;
                            return JSON.stringify(val);
                        }
                        return val;
                    });
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
        // Run post-restore database schema healing, migrations and reset cloud backup to OFF
        await (0, postRestoreHealing_1.runPostRestoreHealing)(activeDb);
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
        const rawStorage = require('./storageQuota.service');
        const StorageQuotaService = rawStorage.default || rawStorage;
        const isEnterpriseFile = sanitized.includes('enterprise') || sanitized.includes('system_full') || sanitized.includes('_all_');
        // SECURITY GUARD: Regular outlets can NEVER access Admin Console enterprise backups
        if (isEnterpriseFile && !isSuperAdmin) {
            return null;
        }
        // 1. If Enterprise / Super Admin: check Admin Console dedicated folder
        if (isSuperAdmin || isEnterpriseFile) {
            try {
                const adminPaths = StorageQuotaService.getAdminConsoleStoragePaths();
                const adminCandidate = path_1.default.join(adminPaths.backupsDir, sanitized);
                if (fs_1.default.existsSync(adminCandidate))
                    return adminCandidate;
            }
            catch (_) { }
        }
        // 2. Direct Outlet Isolated Storage Check (storage/outlets/<outletCode>/backups)
        if (outletCode && outletCode !== 'ALL') {
            try {
                const tenantPaths = StorageQuotaService.getTenantStoragePaths(outletCode);
                const tenantCandidate = path_1.default.join(tenantPaths.backupsDir, sanitized);
                if (fs_1.default.existsSync(tenantCandidate))
                    return tenantCandidate;
            }
            catch (_) { }
        }
        // 3. Fallback search roots (legacy backups/ directory, backward compatibility)
        const searchRoots = getBackupSearchRoots();
        for (const root of searchRoots) {
            const entCandidate = path_1.default.join(root, 'enterprise', sanitized);
            if (fs_1.default.existsSync(entCandidate)) {
                if (!isSuperAdmin && isEnterpriseFile)
                    continue;
                return entCandidate;
            }
            if (outletCode && outletCode !== 'ALL') {
                const outletBackupPath = path_1.default.join(root, 'outlets', outletCode, 'backups', sanitized);
                if (fs_1.default.existsSync(outletBackupPath))
                    return outletBackupPath;
                const outletPath = path_1.default.join(root, 'outlets', outletCode, sanitized);
                if (fs_1.default.existsSync(outletPath))
                    return outletPath;
            }
            const rootCandidate = path_1.default.join(root, sanitized);
            if (fs_1.default.existsSync(rootCandidate)) {
                if (!isSuperAdmin && outletCode && outletCode !== 'ALL') {
                    if (sanitized.includes(outletCode))
                        return rootCandidate;
                }
                else if (isSuperAdmin) {
                    return rootCandidate;
                }
            }
        }
        return null;
    }
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
        const rawStorage = require('./storageQuota.service');
        const StorageQuotaService = rawStorage.default || rawStorage;
        const adminPaths = StorageQuotaService.getAdminConsoleStoragePaths();
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        const filename = `system_full_backup_${timestamp}.posbak`;
        const filePath = path_1.default.join(adminPaths.backupsDir, filename);
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
        // Run post-restore database schema healing, migrations and reset cloud backup to OFF
        await (0, postRestoreHealing_1.runPostRestoreHealing)(activeDb);
        return {
            success: true,
            totalRecordsRestored,
            tablesRestored,
            uploadsRestored,
        };
    }
    /**
     * 10. Create Granular .fambak Backup (All Outlets or Particular Outlet)
     * Supports local file storage, versioned enterprise paths, and Google Drive sync.
     */
    static async createFambakBackup(activeDb, options) {
        const isAll = options.scope === 'ALL';
        const now = new Date();
        const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}-${String(now.getMinutes()).padStart(2, '0')}-${String(now.getSeconds()).padStart(2, '0')}`;
        const tablesToExport = [
            'outlets', 'users', 'system_settings', 'app_branding', 'tax_groups', 'tax_group_components',
            'item_groups', 'subcategories', 'brands', 'item_master', 'batches', 'stock_locations',
            'stock_ledger', 'item_modifiers', 'item_boms', 'customers', 'customer_advances', 'customer_repayments',
            'sales_headers', 'sales_items', 'restaurant_tables', 'table_reservations', 'kot_headers', 'kot_items',
            'purchase_orders', 'purchase_order_items', 'goods_receipts', 'goods_receipt_items', 'supplier_master',
            'supplier_bills', 'supplier_payments', 'clinic_appointments',
            // HRMS & Payroll Complete Suite
            'hr_designations', 'hr_shifts', 'hr_holidays', 'hr_leave_types', 'hr_salary_components',
            'hr_pay_structures', 'hr_pay_structure_components', 'hr_employees', 'hr_biometric_devices',
            'hr_attendance_punches', 'hr_leave_applications', 'hr_leave_balances', 'hr_salary_revisions',
            'hr_arrears', 'hr_loans', 'hr_loan_transactions', 'hr_sales_commissions', 'hr_cashier_handovers',
            'hr_payroll_runs', 'hr_payroll_details',
            'expenses', 'accounting_vouchers', 'voucher_lines', 'bank_accounts', 'cash_ledger',
            'milk_subscriptions', 'milk_subscription_consumptions', 'milk_subscription_items', 'user_notes',
            'numbering_settings', 'paymentMethod', 'saleSource'
        ];
        const backupData = {};
        let totalRecords = 0;
        const outletsList = [];
        let filename = '';
        let targetDirectory = '';
        // DYNAMIC DATABASE-WIDE DISCOVERY: Complete table backup (not just hardcoded list)
        let allPublicTables = [];
        try {
            const tableRows = await activeDb.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;", { type: sequelize_1.QueryTypes.SELECT });
            allPublicTables = tableRows.map((r) => r.table_name || r.TABLE_NAME).filter(Boolean);
        }
        catch (_) {
            allPublicTables = [];
        }
        if (allPublicTables.length === 0) {
            allPublicTables = tablesToExport;
        }
        const rawStorage = require('./storageQuota.service');
        const StorageQuotaService = rawStorage.default || rawStorage;
        if (isAll) {
            const adminPaths = StorageQuotaService.getAdminConsoleStoragePaths();
            targetDirectory = adminPaths.backupsDir;
            filename = `enterprise_backup_all_${timestamp}.fambak`;
            // Read all records for each table
            for (const tbl of allPublicTables) {
                try {
                    const rows = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                    const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                    backupData[tbl] = rowList;
                    totalRecords += rowList.length;
                }
                catch (_) {
                    backupData[tbl] = [];
                }
            }
            // Build outlets manifest
            const allOutlets = backupData.outlets || [];
            if (allOutlets.length > 0) {
                for (const o of allOutlets) {
                    const oId = Number(o.id);
                    let oCount = 0;
                    for (const [tName, rows] of Object.entries(backupData)) {
                        if (tName === 'outlets' || !Array.isArray(rows))
                            continue;
                        oCount += rows.filter(r => r && (r.outlet_id === oId || r.outlet_code === o.outlet_code)).length;
                    }
                    outletsList.push({
                        id: oId,
                        code: o.outlet_code || `OUT_${oId}`,
                        name: o.outlet_name || o.name || `Outlet #${oId}`,
                        business_module: o.business_module || 'ALL',
                        recordCount: oCount,
                    });
                }
            }
            else {
                outletsList.push({
                    id: 1,
                    code: 'DEFAULT',
                    name: 'Primary Enterprise Store',
                    business_module: 'ALL',
                    recordCount: totalRecords,
                });
            }
        }
        else {
            // Scoped Single Outlet - Dynamically resolve outletId and outletCode from database
            let outletId = Number(options.outletId || 0);
            let outletCode = String(options.outletCode || '').trim();
            if (outletCode) {
                try {
                    const [oRow] = await activeDb.query(`SELECT id, outlet_code FROM outlets WHERE outlet_code = :code LIMIT 1;`, { replacements: { code: outletCode }, type: sequelize_1.QueryTypes.SELECT });
                    if (oRow && oRow.id) {
                        outletId = Number(oRow.id);
                        outletCode = String(oRow.outlet_code || outletCode);
                    }
                }
                catch (_) { }
            }
            else if (outletId) {
                try {
                    const [oRow] = await activeDb.query(`SELECT id, outlet_code FROM outlets WHERE id = :id LIMIT 1;`, { replacements: { id: outletId }, type: sequelize_1.QueryTypes.SELECT });
                    if (oRow && oRow.outlet_code) {
                        outletCode = String(oRow.outlet_code);
                    }
                }
                catch (_) { }
            }
            if (!outletId)
                outletId = 1;
            if (!outletCode)
                outletCode = `OUT_${outletId}`;
            const tenantPaths = StorageQuotaService.getTenantStoragePaths(outletCode);
            targetDirectory = tenantPaths.backupsDir;
            filename = `outlet_backup_${outletCode}_${timestamp}.fambak`;
            const outletScopedTables = [
                'item_master', 'batches', 'stock_locations', 'stock_ledger', 'item_modifiers', 'item_boms',
                'customers', 'customer_advances', 'customer_repayments', 'sales_headers', 'restaurant_tables',
                'table_reservations', 'kot_headers', 'purchase_orders', 'goods_receipts', 'supplier_master',
                'supplier_bills', 'supplier_payments', 'clinic_appointments',
                // Complete HR Master & Scoped Tables
                'hr_designations', 'hr_shifts', 'hr_holidays', 'hr_leave_types', 'hr_salary_components',
                'hr_pay_structures', 'hr_employees', 'hr_biometric_devices', 'hr_attendance_punches',
                'hr_leave_applications', 'hr_leave_balances', 'hr_salary_revisions', 'hr_arrears',
                'hr_loans', 'hr_sales_commissions', 'hr_cashier_handovers', 'hr_payroll_runs',
                'expenses', 'accounting_vouchers', 'bank_accounts', 'cash_ledger',
                'milk_subscriptions', 'milk_subscription_consumptions', 'user_notes', 'numbering_settings'
            ];
            for (const tbl of outletScopedTables) {
                try {
                    const rows = await activeDb.query(`SELECT * FROM "${tbl}" WHERE outlet_id = :targetOutletId;`, { replacements: { targetOutletId: outletId }, type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                    const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                    backupData[tbl] = rowList;
                    totalRecords += rowList.length;
                }
                catch (_) {
                    backupData[tbl] = [];
                }
            }
            // Child tables
            const childTables = [
                { name: 'sales_items', fk: 'sale_id', parentTable: 'sales_headers' },
                { name: 'kot_items', fk: 'kot_header_id', parentTable: 'kot_headers' },
                { name: 'purchase_order_items', fk: 'po_id', parentTable: 'purchase_orders' },
                { name: 'goods_receipt_items', fk: 'grn_id', parentTable: 'goods_receipts' },
                { name: 'voucher_lines', fk: 'voucher_id', parentTable: 'accounting_vouchers' },
                { name: 'milk_subscription_items', fk: 'subscription_id', parentTable: 'milk_subscriptions' },
                { name: 'hr_pay_structure_components', fk: 'pay_structure_id', parentTable: 'hr_pay_structures' },
                { name: 'hr_loan_transactions', fk: 'loan_id', parentTable: 'hr_loans' },
                { name: 'hr_payroll_details', fk: 'payroll_run_id', parentTable: 'hr_payroll_runs' },
            ];
            for (const child of childTables) {
                try {
                    const rows = await activeDb.query(`SELECT c.* FROM "${child.name}" c 
             JOIN "${child.parentTable}" p ON c."${child.fk}" = p.id 
             WHERE p.outlet_id = :targetOutletId;`, { replacements: { targetOutletId: outletId }, type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                    const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
                    backupData[child.name] = rowList;
                    totalRecords += rowList.length;
                }
                catch (_) {
                    backupData[child.name] = [];
                }
            }
            // Scoped users & global references
            try {
                const usersRows = await activeDb.query(`SELECT * FROM "users" WHERE outlet_id = :targetOutletId OR outlet_code = :outletCode;`, { replacements: { targetOutletId: outletId, outletCode }, type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                backupData['users'] = Array.isArray(usersRows) ? usersRows : (usersRows?.[0] || []);
                totalRecords += backupData['users'].length;
            }
            catch (_) {
                backupData['users'] = [];
            }
            const refTables = ['system_settings', 'app_branding', 'tax_groups', 'tax_group_components', 'item_groups', 'subcategories', 'brands', 'paymentMethod', 'saleSource'];
            for (const rt of refTables) {
                try {
                    const rows = await activeDb.query(`SELECT * FROM "${rt}";`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                    backupData[rt] = Array.isArray(rows) ? rows : (rows?.[0] || []);
                }
                catch (_) {
                    backupData[rt] = [];
                }
            }
            // Read outlet record
            let outletRec = null;
            try {
                const [oRows] = await activeDb.query(`SELECT * FROM outlets WHERE id = :outletId OR outlet_code = :outletCode LIMIT 1;`, { replacements: { outletId, outletCode }, type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
                outletRec = oRows;
            }
            catch (_) { }
            outletsList.push({
                id: outletId,
                code: outletCode,
                name: outletRec?.outlet_name || options.outletMeta?.outlet_name || options.outletMeta?.name || `Outlet #${outletId}`,
                business_module: outletRec?.business_module || options.outletMeta?.business_module || 'ALL',
                recordCount: totalRecords,
            });
            backupData['outlets'] = outletRec ? [outletRec] : [];
        }
        const payload = {
            format: 'FAMALTH_ENTERPRISE_BACKUP_V3',
            version: '3.0',
            scope: isAll ? 'ALL' : 'OUTLET',
            exportedAt: new Date().toISOString(),
            sourceOutletId: isAll ? null : (options.outletId || 1),
            sourceOutletCode: isAll ? 'ENTERPRISE_ALL' : (options.outletCode || `OUT_${options.outletId || 1}`),
            outlets: outletsList,
            totalRecords,
            tables: backupData,
            metadata: {
                nodeVersion: process.version,
                platform: process.platform,
                generator: 'Famalth Enterprise Backup Engine v3.0'
            }
        };
        const jsonString = JSON.stringify(payload);
        const compressedBuffer = zlib_1.default.gzipSync(Buffer.from(jsonString, 'utf8'), { level: 9 });
        const filePath = path_1.default.join(targetDirectory, filename);
        await promises_1.default.writeFile(filePath, compressedBuffer);
        // Also place in root BACKUP_BASE_DIR for quick access
        const rootPath = path_1.default.join(BACKUP_BASE_DIR, filename);
        try {
            await promises_1.default.copyFile(filePath, rootPath);
        }
        catch (_) { }
        let driveStatus;
        if (options.saveToDrive) {
            try {
                const { uploadFambakToDrive } = require('../modules/driveService');
                driveStatus = await uploadFambakToDrive(filePath, filename, isAll ? 'ALL' : (options.outletCode || 'DEFAULT'));
            }
            catch (dErr) {
                driveStatus = { success: false, message: dErr.message };
            }
        }
        return {
            filename,
            filePath,
            sizeBytes: compressedBuffer.length,
            sizePretty: formatBytes(compressedBuffer.length),
            totalRecords,
            scope: isAll ? 'ALL' : 'OUTLET',
            outlets: outletsList,
            downloadUrl: `/api/backup/download/${encodeURIComponent(filename)}`,
            driveStatus,
        };
    }
    /**
     * 11. Pre-Inspect Backup Manifest (.fambak, .posbak, .zip, .enc, .json)
     * Safely unpacks and parses manifest without modifying database.
     */
    static async inspectBackupManifest(fileBuffer) {
        let jsonText = '';
        if (fileBuffer.length >= 2 && fileBuffer[0] === 0x1f && fileBuffer[1] === 0x8b) {
            jsonText = zlib_1.default.gunzipSync(fileBuffer).toString('utf8');
        }
        else if (fileBuffer.length >= 4 && fileBuffer[0] === 0x50 && fileBuffer[1] === 0x4B) {
            const unzipper = require('unzipper');
            const directory = await unzipper.Open.buffer(fileBuffer);
            for (const f of directory.files) {
                if (f.path === 'database.json' || f.path === 'manifest.json') {
                    jsonText = (await f.buffer()).toString('utf8');
                    break;
                }
            }
        }
        else {
            jsonText = fileBuffer.toString('utf8');
        }
        let payload;
        try {
            payload = JSON.parse(jsonText);
        }
        catch (e) {
            throw new Error(`Invalid or corrupted backup archive: ${e.message}`);
        }
        const tables = payload.tables || {};
        const tableSummaries = [];
        let calculatedTotal = 0;
        for (const [tName, rows] of Object.entries(tables)) {
            if (Array.isArray(rows)) {
                tableSummaries.push({ name: tName, count: rows.length });
                calculatedTotal += rows.length;
            }
        }
        let outlets = payload.outlets || [];
        if (!Array.isArray(outlets) || outlets.length === 0) {
            if (tables.outlets && Array.isArray(tables.outlets) && tables.outlets.length > 0) {
                outlets = tables.outlets.map((o) => ({
                    id: o.id || 1,
                    code: o.outlet_code || `OUT_${o.id || 1}`,
                    name: o.outlet_name || o.name || `Outlet #${o.id || 1}`,
                    business_module: o.business_module || 'ALL',
                    recordCount: calculatedTotal,
                }));
            }
            else if (payload.sourceOutletId || payload.outletCode || payload.sourceOutletCode) {
                outlets = [{
                        id: payload.sourceOutletId || 1,
                        code: payload.sourceOutletCode || payload.outletCode || 'DEFAULT',
                        name: payload.outletMeta?.name || 'Store',
                        business_module: payload.outletMeta?.business_module || 'ALL',
                        recordCount: calculatedTotal,
                    }];
            }
        }
        const scope = payload.scope === 'ALL' || (outlets.length > 1) ? 'ALL' : 'OUTLET';
        return {
            format: payload.format || 'FAMALTH_ARCHIVE',
            version: payload.version || '3.0',
            scope,
            exportedAt: payload.exportedAt || payload.createdAt || new Date().toISOString(),
            sourceOutletCode: payload.sourceOutletCode || payload.outletCode || (scope === 'ALL' ? 'ENTERPRISE_ALL' : 'SINGLE_OUTLET'),
            totalRecords: payload.totalRecords || calculatedTotal,
            outlets,
            tables: tableSummaries,
        };
    }
    /**
     * 12. Upgraded Granular Restore (.fambak)
     * Supports Selective Outlet Restore from Complete Backup or Single Outlet Backup,
     * safe rollback-capable database transaction, and auto-sequence synchronization.
     */
    static async restoreFambakBackup(activeDb, fileBuffer, options = {}) {
        const manifest = await this.inspectBackupManifest(fileBuffer);
        let jsonText = '';
        if (fileBuffer.length >= 2 && fileBuffer[0] === 0x1f && fileBuffer[1] === 0x8b) {
            jsonText = zlib_1.default.gunzipSync(fileBuffer).toString('utf8');
        }
        else if (fileBuffer.length >= 4 && fileBuffer[0] === 0x50 && fileBuffer[1] === 0x4B) {
            const unzipper = require('unzipper');
            const directory = await unzipper.Open.buffer(fileBuffer);
            for (const f of directory.files) {
                if (f.path === 'database.json') {
                    jsonText = (await f.buffer()).toString('utf8');
                    break;
                }
            }
        }
        else {
            jsonText = fileBuffer.toString('utf8');
        }
        const payload = JSON.parse(jsonText);
        const tables = payload.tables || {};
        let totalRecordsRestored = 0;
        const tablesRestored = [];
        const colMap = new Map();
        try {
            const tableCols = await activeDb.query(`SELECT table_name, column_name, data_type 
         FROM information_schema.columns 
         WHERE table_schema = 'public'`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
            for (const c of tableCols) {
                const tName = Array.isArray(c) ? c[0] : (c.table_name || c.TABLE_NAME);
                const colName = Array.isArray(c) ? c[1] : (c.column_name || c.COLUMN_NAME);
                const dType = Array.isArray(c) ? c[2] : (c.data_type || c.DATA_TYPE);
                if (!tName || !colName)
                    continue;
                if (!colMap.has(tName))
                    colMap.set(tName, new Map());
                colMap.get(tName).set(colName, dType);
            }
        }
        catch (_) { }
        // Dynamic discovery of existing base tables in public schema
        let existingTables = new Set();
        try {
            const tRows = await activeDb.query(`SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
            existingTables = new Set(tRows.map((r) => Array.isArray(r) ? r[0] : (r?.table_name || r?.TABLE_NAME || r)).filter(Boolean));
        }
        catch (_) { }
        // Primary key mapping for intelligent upserts
        const pkMap = new Map();
        try {
            const pkRows = await activeDb.query(`
        SELECT kcu.table_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
          ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = 'public';
      `, { type: sequelize_1.QueryTypes.SELECT }).catch(() => []);
            for (const r of pkRows) {
                const tName = Array.isArray(r) ? r[0] : (r.table_name || r.TABLE_NAME);
                const colName = Array.isArray(r) ? r[1] : (r.column_name || r.COLUMN_NAME);
                if (!tName || !colName)
                    continue;
                if (!pkMap.has(tName))
                    pkMap.set(tName, []);
                pkMap.get(tName).push(colName);
            }
        }
        catch (_) { }
        const masterEntityTables = new Set([
            'tax_groups', 'tax_group_components', 'item_groups', 'subcategories', 'brands',
            'system_settings', 'app_branding', 'paymentMethod', 'saleSource', 'numbering_settings',
            'stock_locations', 'item_master', 'item_modifiers', 'item_boms',
            'customers', 'supplier_master', 'restaurant_tables', 'table_reservations',
            'hr_designations', 'hr_shifts', 'hr_holidays', 'hr_leave_types', 'hr_salary_components', 'hr_pay_structures', 'hr_employees', 'hr_biometric_devices', 'bank_accounts'
        ]);
        // Topological dependency order: Independent Masters -> Purchases -> Sales -> Sales-Dependents -> Ledgers
        const restoreOrder = [
            // 1. Masters
            'tax_groups', 'tax_group_components', 'item_groups', 'subcategories', 'brands',
            'system_settings', 'app_branding', 'paymentMethod', 'saleSource', 'numbering_settings',
            'stock_locations', 'item_master', 'item_modifiers', 'item_boms',
            'customers', 'supplier_master', 'bank_accounts', 'restaurant_tables', 'table_reservations',
            'hr_designations', 'hr_shifts', 'hr_holidays', 'hr_leave_types', 'hr_salary_components',
            'hr_pay_structures', 'hr_pay_structure_components', 'hr_employees', 'hr_biometric_devices',
            // 2. Purchases & GRN
            'purchase_orders', 'purchase_order_items',
            'goods_receipts', 'goods_receipt_items', 'supplier_bills', 'supplier_payments',
            // 3. Sales Headers & Items
            'sales_headers', 'sales_items',
            // 4. Sales-Dependent Collections, Advances & Kitchen
            'customer_advances', 'customer_repayments',
            'sales_credit_notes', 'sales_refunds',
            'kot_headers', 'kot_items',
            'clinic_appointments',
            'milk_subscriptions', 'milk_subscription_items', 'milk_subscription_consumptions',
            // 5. HRMS & Payroll
            'hr_loans', 'hr_loan_transactions', 'hr_leave_balances', 'hr_leave_applications',
            'hr_salary_revisions', 'hr_arrears', 'hr_attendance_punches',
            'hr_sales_commissions', 'hr_cashier_handovers', 'hr_payroll_runs', 'hr_payroll_details',
            // 6. Financial & Stock Ledgers
            'expenses', 'accounting_vouchers', 'voucher_lines', 'cash_ledger', 'stock_ledger',
            'user_notes', 'users'
        ];
        const isSelectiveOutlet = Boolean(options.selectedOutletCode) || options.scope === 'OUTLET' || manifest.scope === 'OUTLET';
        if (isSelectiveOutlet) {
            const selectedCode = (options.selectedOutletCode || manifest.sourceOutletCode || (manifest.outlets[0]?.code) || '').trim();
            const matchedOutlet = manifest.outlets.find(o => String(o.code).toLowerCase() === selectedCode.toLowerCase()) || manifest.outlets[0];
            const sourceOutletId = matchedOutlet ? Number(matchedOutlet.id) : Number(manifest.outlets[0]?.id || 1);
            let destOutletCode = String(options.targetOutletCode || selectedCode || `OUT_${options.targetOutletId || 1}`).trim();
            let destOutletId = Number(options.targetOutletId || 0);
            // Resolve destination outlet dynamically from DB by code if needed
            if (destOutletCode) {
                try {
                    const [foundOutlet] = await activeDb.query(`SELECT id, outlet_code FROM outlets WHERE outlet_code = :destOutletCode LIMIT 1;`, { replacements: { destOutletCode }, type: sequelize_1.QueryTypes.SELECT });
                    if (foundOutlet && foundOutlet.id) {
                        destOutletId = Number(foundOutlet.id);
                        destOutletCode = foundOutlet.outlet_code;
                    }
                }
                catch (_) { }
            }
            if (!destOutletId && options.targetOutletId) {
                destOutletId = Number(options.targetOutletId);
            }
            if (!destOutletId) {
                destOutletId = Number(sourceOutletId || 1);
            }
            await activeDb.transaction(async (t) => {
                const [existingOutlet] = await activeDb.query(`SELECT id, outlet_code FROM outlets WHERE id = :destOutletId OR outlet_code = :destOutletCode LIMIT 1;`, { replacements: { destOutletId, destOutletCode }, type: sequelize_1.QueryTypes.SELECT, transaction: t }).catch(() => []);
                if (!existingOutlet) {
                    await activeDb.query(`INSERT INTO outlets (id, outlet_code, outlet_name, business_module, created_at, updated_at)
             VALUES (:destOutletId, :destOutletCode, :name, :bizModule, NOW(), NOW())
             ON CONFLICT (id) DO UPDATE SET outlet_code = :destOutletCode;`, {
                        replacements: {
                            destOutletId,
                            destOutletCode,
                            name: matchedOutlet?.name || `Outlet ${destOutletCode}`,
                            bizModule: matchedOutlet?.business_module || 'ALL',
                        },
                        transaction: t,
                    }).catch(() => { });
                }
                if (options.overwriteExisting) {
                    // Break self/circular references before deletion so FK constraints do not abort transaction
                    if (existingTables.has('sales_headers')) {
                        await activeDb.query(`UPDATE "sales_headers" SET original_sale_id = NULL, previous_sale_id = NULL, replaced_by_sale_id = NULL WHERE outlet_id = :destOutletId;`, { replacements: { destOutletId }, transaction: t }).catch(() => { });
                    }
                    if (existingTables.has('kot_headers')) {
                        await activeDb.query(`UPDATE "kot_headers" SET sales_header_id = NULL WHERE outlet_id = :destOutletId;`, { replacements: { destOutletId }, transaction: t }).catch(() => { });
                    }
                    // Strict reverse-dependency ordered child deletes with table existence check
                    const safeChildDeletes = [
                        { tbl: 'sales_credit_notes', q: `DELETE FROM "sales_credit_notes" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'sales_refunds', q: `DELETE FROM "sales_refunds" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'customer_loyalty_ledger', q: `DELETE FROM "customer_loyalty_ledger" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'draw_vouchers', q: `DELETE FROM "draw_vouchers" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'hr_sales_commissions', q: `DELETE FROM "hr_sales_commissions" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'customer_item_advances', q: `DELETE FROM "customer_item_advances" WHERE outlet_id = :destOutletId` },
                        { tbl: 'customer_advances', q: `DELETE FROM "customer_advances" WHERE outlet_id = :destOutletId` },
                        { tbl: 'customer_repayments', q: `DELETE FROM "customer_repayments" WHERE outlet_id = :destOutletId` },
                        { tbl: 'milk_subscription_consumptions', q: `DELETE FROM "milk_subscription_consumptions" WHERE outlet_id = :destOutletId` },
                        { tbl: 'milk_subscription_items', q: `DELETE FROM "milk_subscription_items" WHERE subscription_id IN (SELECT id FROM "milk_subscriptions" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'milk_subscriptions', q: `DELETE FROM "milk_subscriptions" WHERE outlet_id = :destOutletId` },
                        { tbl: 'sales_items', q: `DELETE FROM "sales_items" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'clinic_appointments', q: `DELETE FROM "clinic_appointments" WHERE outlet_id = :destOutletId` },
                        { tbl: 'kot_items', q: `DELETE FROM "kot_items" WHERE kot_header_id IN (SELECT id FROM "kot_headers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'kot_headers', q: `DELETE FROM "kot_headers" WHERE outlet_id = :destOutletId` },
                        { tbl: 'sales_headers', q: `DELETE FROM "sales_headers" WHERE outlet_id = :destOutletId` },
                        { tbl: 'purchase_order_items', q: `DELETE FROM "purchase_order_items" WHERE po_id IN (SELECT id FROM "purchase_orders" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'purchase_orders', q: `DELETE FROM "purchase_orders" WHERE outlet_id = :destOutletId` },
                        { tbl: 'goods_receipt_items', q: `DELETE FROM "goods_receipt_items" WHERE grn_id IN (SELECT id FROM "goods_receipts" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'goods_receipts', q: `DELETE FROM "goods_receipts" WHERE outlet_id = :destOutletId` },
                        { tbl: 'voucher_lines', q: `DELETE FROM "voucher_lines" WHERE voucher_id IN (SELECT id FROM "accounting_vouchers" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'accounting_vouchers', q: `DELETE FROM "accounting_vouchers" WHERE outlet_id = :destOutletId` },
                        { tbl: 'supplier_bills', q: `DELETE FROM "supplier_bills" WHERE outlet_id = :destOutletId` },
                        { tbl: 'supplier_payments', q: `DELETE FROM "supplier_payments" WHERE outlet_id = :destOutletId` },
                        { tbl: 'expenses', q: `DELETE FROM "expenses" WHERE outlet_id = :destOutletId` },
                        { tbl: 'cash_ledger', q: `DELETE FROM "cash_ledger" WHERE outlet_id = :destOutletId` },
                        { tbl: 'stock_ledger', q: `DELETE FROM "stock_ledger" WHERE outlet_id = :destOutletId` },
                        { tbl: 'table_reservations', q: `DELETE FROM "table_reservations" WHERE outlet_id = :destOutletId` },
                        { tbl: 'restaurant_tables', q: `DELETE FROM "restaurant_tables" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_payroll_details', q: `DELETE FROM "hr_payroll_details" WHERE payroll_run_id IN (SELECT id FROM "hr_payroll_runs" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'hr_payroll_runs', q: `DELETE FROM "hr_payroll_runs" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_loan_transactions', q: `DELETE FROM "hr_loan_transactions" WHERE loan_id IN (SELECT id FROM "hr_loans" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'hr_loans', q: `DELETE FROM "hr_loans" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_arrears', q: `DELETE FROM "hr_arrears" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_salary_revisions', q: `DELETE FROM "hr_salary_revisions" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_leave_applications', q: `DELETE FROM "hr_leave_applications" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_leave_balances', q: `DELETE FROM "hr_leave_balances" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_cashier_handovers', q: `DELETE FROM "hr_cashier_handovers" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_attendance_punches', q: `DELETE FROM "hr_attendance_punches" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_pay_structure_components', q: `DELETE FROM "hr_pay_structure_components" WHERE pay_structure_id IN (SELECT id FROM "hr_pay_structures" WHERE outlet_id = :destOutletId)` },
                        { tbl: 'hr_pay_structures', q: `DELETE FROM "hr_pay_structures" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_salary_components', q: `DELETE FROM "hr_salary_components" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_leave_types', q: `DELETE FROM "hr_leave_types" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_shifts', q: `DELETE FROM "hr_shifts" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_holidays', q: `DELETE FROM "hr_holidays" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_designations', q: `DELETE FROM "hr_designations" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_biometric_devices', q: `DELETE FROM "hr_biometric_devices" WHERE outlet_id = :destOutletId` },
                        { tbl: 'hr_employees', q: `DELETE FROM "hr_employees" WHERE outlet_id = :destOutletId` },
                        { tbl: 'user_notes', q: `DELETE FROM "user_notes" WHERE outlet_id = :destOutletId` }
                    ];
                    for (const item of safeChildDeletes) {
                        if (existingTables.size === 0 || existingTables.has(item.tbl)) {
                            try {
                                await activeDb.query(item.q, { replacements: { destOutletId }, transaction: t });
                            }
                            catch (_) { }
                        }
                    }
                }
                for (const tbl of restoreOrder) {
                    if (existingTables.size > 0 && !existingTables.has(tbl))
                        continue;
                    const rawRows = tables[tbl];
                    if (!Array.isArray(rawRows) || rawRows.length === 0)
                        continue;
                    const validColMap = colMap.get(tbl);
                    if (colMap.size > 0 && !validColMap)
                        continue;
                    const pks = pkMap.get(tbl) || [];
                    // Filter rows for this specific outlet
                    const scopedRows = rawRows.filter(row => {
                        if (!row || typeof row !== 'object')
                            return false;
                        if ('outlet_id' in row)
                            return Number(row.outlet_id) === sourceOutletId;
                        if ('outlet_code' in row)
                            return String(row.outlet_code).toLowerCase() === selectedCode.toLowerCase();
                        return true; // Global master table rows included
                    });
                    if (scopedRows.length === 0)
                        continue;
                    for (const row of scopedRows) {
                        const rowCopy = { ...row };
                        if ('outlet_id' in rowCopy)
                            rowCopy.outlet_id = destOutletId;
                        if ('outlet_code' in rowCopy)
                            rowCopy.outlet_code = destOutletCode;
                        const cols = Object.keys(rowCopy).filter(c => !validColMap || validColMap.has(c));
                        if (cols.length === 0)
                            continue;
                        const colList = cols.map(c => `"${c}"`).join(', ');
                        const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                        const values = cols.map(c => {
                            const val = rowCopy[c];
                            const dtype = validColMap ? validColMap.get(c) : null;
                            if (val !== null && typeof val === 'object' && !(val instanceof Date) && !Buffer.isBuffer(val)) {
                                return JSON.stringify(val);
                            }
                            if (dtype === 'json' || dtype === 'jsonb') {
                                return typeof val === 'string' ? val : JSON.stringify(val);
                            }
                            return val;
                        });
                        // Upsert strategy: Overwrite on Rollback, or Merge upsert for Entity Masters
                        const shouldUpsert = options.overwriteExisting === true || masterEntityTables.has(tbl);
                        let sql = `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders})`;
                        if (shouldUpsert && pks.length > 0) {
                            const nonPkCols = cols.filter(c => !pks.includes(c));
                            if (nonPkCols.length > 0) {
                                const updateClause = nonPkCols.map(c => `"${c}" = EXCLUDED."${c}"`).join(', ');
                                sql += ` ON CONFLICT (${pks.map(c => `"${c}"`).join(', ')}) DO UPDATE SET ${updateClause};`;
                            }
                            else {
                                sql += ` ON CONFLICT DO NOTHING;`;
                            }
                        }
                        else {
                            sql += ` ON CONFLICT DO NOTHING;`;
                        }
                        try {
                            await activeDb.query(sql, { bind: values, transaction: t });
                            totalRecordsRestored++;
                        }
                        catch (_) { }
                    }
                    tablesRestored.push(tbl);
                }
                // Sequence reset
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
            // Run post-restore database schema healing, migrations and reset cloud backup to OFF
            await (0, postRestoreHealing_1.runPostRestoreHealing)(activeDb);
            return {
                success: true,
                totalRecordsRestored,
                tablesRestored,
                restoredOutletCode: destOutletCode,
                targetOutletId: destOutletId,
            };
        }
        else {
            // Full Enterprise Restore
            await activeDb.transaction(async (t) => {
                for (const tbl of restoreOrder) {
                    if (existingTables.size > 0 && !existingTables.has(tbl))
                        continue;
                    const rows = tables[tbl];
                    if (!Array.isArray(rows) || rows.length === 0)
                        continue;
                    const validColMap = colMap.get(tbl);
                    if (colMap.size > 0 && !validColMap)
                        continue;
                    const pks = pkMap.get(tbl) || [];
                    for (const row of rows) {
                        const cols = Object.keys(row).filter(c => !validColMap || validColMap.has(c));
                        if (cols.length === 0)
                            continue;
                        const colList = cols.map(c => `"${c}"`).join(', ');
                        const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
                        const values = cols.map(c => {
                            const val = row[c];
                            const dtype = validColMap ? validColMap.get(c) : null;
                            if (val !== null && typeof val === 'object' && !(val instanceof Date) && !Buffer.isBuffer(val)) {
                                return JSON.stringify(val);
                            }
                            if (dtype === 'json' || dtype === 'jsonb') {
                                return typeof val === 'string' ? val : JSON.stringify(val);
                            }
                            return val;
                        });
                        const shouldUpsert = options.overwriteExisting === true || masterEntityTables.has(tbl);
                        let sql = `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders})`;
                        if (shouldUpsert && pks.length > 0) {
                            const nonPkCols = cols.filter(c => !pks.includes(c));
                            if (nonPkCols.length > 0) {
                                const updateClause = nonPkCols.map(c => `"${c}" = EXCLUDED."${c}"`).join(', ');
                                sql += ` ON CONFLICT (${pks.map(c => `"${c}"`).join(', ')}) DO UPDATE SET ${updateClause};`;
                            }
                            else {
                                sql += ` ON CONFLICT DO NOTHING;`;
                            }
                        }
                        else {
                            sql += ` ON CONFLICT DO NOTHING;`;
                        }
                        try {
                            await activeDb.query(sql, { bind: values, transaction: t });
                            totalRecordsRestored++;
                        }
                        catch (_) { }
                    }
                    tablesRestored.push(tbl);
                }
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
            // Run post-restore database schema healing, migrations and reset cloud backup to OFF
            await (0, postRestoreHealing_1.runPostRestoreHealing)(activeDb);
            return {
                success: true,
                totalRecordsRestored,
                tablesRestored,
                restoredOutletCode: 'ALL',
                targetOutletId: null,
            };
        }
    }
    /**
     * 13. List Cloud Snapshots & Remote Backups
     */
    static async listCloudSnapshots(outletCode, isSuperAdmin = false) {
        const searchRoots = getBackupSearchRoots();
        const allowed = ['.fambak', '.posbak', '.enc', '.zip'];
        const collected = [];
        const seenFiles = new Set();
        for (const root of searchRoots) {
            const allFiles = await getDirectorySizeAndFiles(root, allowed);
            for (const f of allFiles.files) {
                if (seenFiles.has(f.name))
                    continue;
                seenFiles.add(f.name);
                const isEnterprise = f.name.includes('all') || f.name.includes('enterprise') || f.name.includes('system_full');
                let fileOutlet = 'ALL';
                if (!isEnterprise) {
                    const match = f.name.match(/(?:outlet_backup|tenant_backup)_([^_]+)_/);
                    if (match && match[1])
                        fileOutlet = match[1];
                }
                // STRICT OUTLET DATA ISOLATION:
                // If an outlet is specified (outletCode !== 'ALL'), only return files for this specific outlet.
                // Enterprise full backups and other outlets are strictly excluded.
                if (outletCode && outletCode !== 'ALL') {
                    if (fileOutlet !== outletCode) {
                        continue;
                    }
                }
                else if (!isSuperAdmin) {
                    continue;
                }
                collected.push({
                    filename: f.name,
                    sizeBytes: f.size,
                    sizePretty: formatBytes(f.size),
                    createdAt: f.mtime.toISOString(),
                    timeAgo: timeSince(f.mtime),
                    scope: isEnterprise ? 'ALL' : 'OUTLET',
                    outletCode: fileOutlet,
                    storageLocation: f.path.includes('enterprise') ? 'ENTERPRISE_CLOUD' : (f.path.includes('outlets') ? 'TENANT_ISOLATED' : 'LOCAL_SERVER'),
                    downloadUrl: `/api/backup/download/${encodeURIComponent(f.name)}`,
                });
            }
        }
        return collected.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }
}
exports.TenantBackupService = TenantBackupService;
exports.default = TenantBackupService;
