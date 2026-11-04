import fs from 'fs';
import fsPromises from 'fs/promises';
import path from 'path';
import zlib from 'zlib';
import crypto from 'crypto';
import { QueryTypes } from 'sequelize';
const archiver = require('archiver');

const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
const canonicalRootDir = path.basename(rootDir) === 'backend' ? path.dirname(rootDir) : rootDir;
const BACKUP_BASE_DIR = path.join(canonicalRootDir, 'backups');

function getBackupSearchRoots(): string[] {
  const current = process.cwd();
  const roots = [
    BACKUP_BASE_DIR,
    path.join(canonicalRootDir, 'backend', 'backups'),
    path.join(current, 'backups'),
    path.join(current, 'backend', 'backups'),
  ];
  return [...new Set(roots)].filter(d => fs.existsSync(d));
}

export interface StorageBreakdown {
  backupsBytes: number;
  backupsPretty: string;
  backupsCount: number;
  uploadsBytes: number;
  uploadsPretty: string;
  databaseBytes: number;
  databasePretty: string;
}

export interface BackupItem {
  filename: string;
  sizeBytes: number;
  sizePretty: string;
  createdAt: string;
  timeAgo: string;
  downloadUrl: string;
}

export interface StorageStatsResult {
  totalUsedBytes: number;
  totalFreeBytes: number;
  totalDiskBytes: number;
  totalUsedPretty: string;
  totalFreePretty: string;
  percentageUsed: number;
  breakdown: StorageBreakdown;
  latestBackup: BackupItem | null;
  backupsList: BackupItem[];
}

export interface OutletStorageDetail {
  outletId: number;
  outletCode: string;
  outletName: string;
  businessModule: string;
  recordCount: number;
  databaseBytes: number;
  databasePretty: string;
  bandwidthBytes: number;
  bandwidthPretty: string;
  backupsBytes: number;
  backupsPretty: string;
  backupsCount: number;
  uploadsBytes: number;
  uploadsPretty: string;
  totalBytes: number;
  totalPretty: string;
  percentageOfUsed: number;
  latestBackupTime: string | null;
  latestBackupTimeAgo: string;
}

export interface EnterpriseStorageAnalyticsResult {
  systemStorage: StorageStatsResult;
  totalOutletsCount: number;
  outletStorageList: OutletStorageDetail[];
}

function formatBytes(bytes: number, decimals: number = 1): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}

function timeSince(date: Date): string {
  const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
  if (seconds < 60) return 'just now';
  let interval = Math.floor(seconds / 31536000);
  if (interval >= 1) return `${interval} year${interval === 1 ? '' : 's'} ago`;
  interval = Math.floor(seconds / 2592000);
  if (interval >= 1) return `${interval} month${interval === 1 ? '' : 's'} ago`;
  interval = Math.floor(seconds / 86400);
  if (interval >= 1) return `${interval} day${interval === 1 ? '' : 's'} ago`;
  interval = Math.floor(seconds / 3600);
  if (interval >= 1) return `${interval} hour${interval === 1 ? '' : 's'} ago`;
  interval = Math.floor(seconds / 60);
  if (interval >= 1) return `${interval} minute${interval === 1 ? '' : 's'} ago`;
  return `${Math.floor(seconds)} seconds ago`;
}

async function getDirectorySizeAndFiles(dirPath: string, allowedExts: string[] = []): Promise<{ size: number; count: number; files: { path: string; name: string; size: number; mtime: Date }[] }> {
  let totalSize = 0;
  let fileCount = 0;
  const fileList: { path: string; name: string; size: number; mtime: Date }[] = [];

  if (!fs.existsSync(dirPath)) {
    return { size: 0, count: 0, files: [] };
  }

  async function walk(currentDir: string) {
    try {
      const entries = await fsPromises.readdir(currentDir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        if (entry.isDirectory()) {
          await walk(fullPath);
        } else if (entry.isFile()) {
          if (allowedExts.length > 0) {
            const ext = path.extname(entry.name).toLowerCase();
            if (!allowedExts.includes(ext)) continue;
          }
          const stat = await fsPromises.stat(fullPath);
          totalSize += stat.size;
          fileCount++;
          fileList.push({ path: fullPath, name: entry.name, size: stat.size, mtime: stat.mtime });
        }
      }
    } catch (_) {}
  }

  await walk(dirPath);
  return { size: totalSize, count: fileCount, files: fileList };
}

export class TenantBackupService {
  /**
   * 1. Get Enterprise Storage Usage and Backup Status
   */
  public static async getStorageStats(activeDb: any, outletCode: string, isSuperAdmin: boolean = false): Promise<StorageStatsResult> {
    let totalDiskBytes = 100 * 1024 * 1024 * 1024; // 100GB default fallback
    let totalFreeBytes = 50 * 1024 * 1024 * 1024;
    let totalUsedBytes = totalDiskBytes - totalFreeBytes;

    try {
      if (fsPromises.statfs) {
        const stat = await fsPromises.statfs(canonicalRootDir);
        const bsize = stat.bsize || 4096;
        totalDiskBytes = Number(stat.blocks) * bsize;
        totalFreeBytes = Number(stat.bavail || stat.bfree) * bsize;
        totalUsedBytes = totalDiskBytes - totalFreeBytes;
      }
    } catch (_) {}

    // Backups directory audit
    const backupAllowed = ['.fambak', '.posbak', '.enc', '.zip', '.sql', '.gz'];
    let backupDirData: { size: number; count: number; files: { path: string; name: string; size: number; mtime: Date }[] };

    if (!isSuperAdmin && outletCode && outletCode !== 'ALL' && outletCode !== 'DEFAULT') {
      // CLIENT-ISOLATED: Strict scoping - only this merchant's backups
      const clientFiles: { path: string; name: string; size: number; mtime: Date }[] = [];
      let clientSize = 0;

      for (const root of getBackupSearchRoots()) {
        const outletSubdir = path.join(root, 'outlets', outletCode);
        const subData = await getDirectorySizeAndFiles(outletSubdir, ['.fambak', '.posbak', '.zip', '.gz']);
        for (const sf of subData.files) {
          if (!clientFiles.some(f => f.name === sf.name)) {
            clientFiles.push(sf);
            clientSize += sf.size;
          }
        }

        // Also check any tenant posbak in root matching tenant_backup_<outletCode>
        if (fs.existsSync(root)) {
          try {
            const rootEntries = await fsPromises.readdir(root, { withFileTypes: true });
            for (const entry of rootEntries) {
              if (entry.isFile() && entry.name.startsWith(`tenant_backup_${outletCode}_`)) {
                const fPath = path.join(root, entry.name);
                const stat = await fsPromises.stat(fPath);
                if (!clientFiles.some(f => f.name === entry.name)) {
                  clientFiles.push({ path: fPath, name: entry.name, size: stat.size, mtime: stat.mtime });
                  clientSize += stat.size;
                }
              }
            }
          } catch (_) {}
        }
      }

      backupDirData = {
        size: clientSize,
        count: clientFiles.length,
        files: clientFiles,
      };
    } else {
      // Full enterprise audit
      backupDirData = await getDirectorySizeAndFiles(BACKUP_BASE_DIR, backupAllowed);
    }

    // Uploads directory audit
    const uploadsDir = path.join(rootDir, 'uploads');
    const publicUploadsDir = path.join(rootDir, 'public', 'uploads');
    const uploadsData1 = await getDirectorySizeAndFiles(uploadsDir);
    const uploadsData2 = await getDirectorySizeAndFiles(publicUploadsDir);
    const totalUploadsBytes = uploadsData1.size + uploadsData2.size;

    // Database size query
    let databaseBytes = 0;
    try {
      if (activeDb && typeof activeDb.query === 'function') {
        const [dbSizeRes]: any = await activeDb.query('SELECT pg_database_size(current_database()) as db_bytes;', { type: QueryTypes.SELECT });
        if (dbSizeRes && dbSizeRes.db_bytes) {
          databaseBytes = Number(dbSizeRes.db_bytes);
        }
      }
    } catch (_) {}

    // Sort backups by modification date descending
    const sortedFiles = backupDirData.files.sort((a, b) => b.mtime.getTime() - a.mtime.getTime());

    const backupsList: BackupItem[] = sortedFiles.map((f) => ({
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
  public static async getEnterpriseStorageAnalytics(activeDb: any): Promise<EnterpriseStorageAnalyticsResult> {
    const systemStorage = await this.getStorageStats(activeDb, 'ALL');

    const outletsResult: any = await activeDb.query(
      `SELECT id, outlet_code, outlet_name, business_module, created_at FROM outlets ORDER BY id ASC;`,
      { type: QueryTypes.SELECT }
    ).catch(() => []);

    const outletList = Array.isArray(outletsResult) ? outletsResult : (outletsResult?.[0] || []);
    const tablesToTrack = [
      'sales_headers', 'item_master', 'stock_ledger', 'customers',
      'goods_receipts', 'purchase_orders', 'kot_headers', 'expenses',
      'clinic_appointments', 'hr_attendance_punches', 'restaurant_tables',
      'accounting_vouchers', 'user_notes', 'milk_subscriptions'
    ];

    const outletRowCounts: Record<number, number> = {};
    outletList.forEach((o: any) => { outletRowCounts[o.id] = 0; });

    let totalTrackedRows = 0;
    for (const tbl of tablesToTrack) {
      try {
        const rows: any = await activeDb.query(
          `SELECT outlet_id, count(*)::int as count FROM "${tbl}" GROUP BY outlet_id;`,
          { type: QueryTypes.SELECT }
        ).catch(() => []);
        const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
        for (const r of rowList) {
          const count = Number(r.count || 0);
          if (outletRowCounts[r.outlet_id] !== undefined) {
            outletRowCounts[r.outlet_id] += count;
          }
          totalTrackedRows += count;
        }
      } catch (_) {}
    }

    const totalDbBytes = systemStorage.breakdown.databaseBytes || 1;
    const outletStorageList: OutletStorageDetail[] = [];

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
      const outletBackupDir = path.join(BACKUP_BASE_DIR, 'outlets', oCode);
      const backupData = await getDirectorySizeAndFiles(outletBackupDir, ['.fambak', '.posbak', '.enc', '.zip', '.sql']);

      const matchingRootBackups = rootBackupCheck.files.filter(f => f.name.includes(oCode));
      const totalBackupsBytes = backupData.size + matchingRootBackups.reduce((acc, f) => acc + f.size, 0);
      const totalBackupsCount = backupData.count + matchingRootBackups.length;

      // Identify latest backup for this outlet
      const allOutletBackupFiles = [...backupData.files, ...matchingRootBackups].sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
      const latestBackupTime = allOutletBackupFiles.length > 0 ? allOutletBackupFiles[0].mtime.toISOString() : null;
      const latestBackupTimeAgo = allOutletBackupFiles.length > 0 ? timeSince(allOutletBackupFiles[0].mtime) : 'No backups';

      // Check uploads for this outlet (uploads/items/<outlet_id>, etc.)
      const outletUploadsDir = path.join(rootDir, 'uploads', 'items', String(oId));
      const uploadsData = await getDirectorySizeAndFiles(outletUploadsDir);

      const totalOutletBytes = estDbBytes + totalBackupsBytes + uploadsData.size;
      const totalSystemUsed = systemStorage.totalUsedBytes || 1;
      const percentageOfUsed = parseFloat(((totalOutletBytes / totalSystemUsed) * 100).toFixed(2));

      // Calculate monthly sync bandwidth footprint (sync API exchanges + uploads + backups)
      const estBandwidthBytes = Math.round(
        (rowCount * 3500) + (totalBackupsBytes * 0.4) + (uploadsData.size * 1.2) + (rowCount > 0 ? 1024 * 1024 * 5 : 0)
      );

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
  public static async createTenantBackup(
    activeDb: any,
    outletId: number,
    outletCode: string,
    outletMeta: any = {}
  ): Promise<{ filename: string; filePath: string; sizeBytes: number; sizePretty: string; totalRecords: number; downloadUrl: string }> {
    const targetOutletId = Number(outletId);
    if (!targetOutletId) throw new Error('Valid target outlet ID is required for tenant backup.');

    const outletDir = path.join(BACKUP_BASE_DIR, 'outlets', outletCode || `outlet_${targetOutletId}`);
    await fsPromises.mkdir(outletDir, { recursive: true });

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

    const backupData: Record<string, any[]> = {};
    let totalRecords = 0;

    for (const tbl of scopedTables) {
      try {
        const rows: any[] = await activeDb.query(
          `SELECT * FROM "${tbl}" WHERE outlet_id = :targetOutletId;`,
          {
            replacements: { targetOutletId },
            type: QueryTypes.SELECT,
          }
        );
        backupData[tbl] = rows || [];
        totalRecords += (rows || []).length;
      } catch (err: any) {
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
        const rows: any[] = await activeDb.query(
          `SELECT c.* FROM "${child.name}" c 
           JOIN "${child.parentTable}" p ON c."${child.fk}" = p.id 
           WHERE p.outlet_id = :targetOutletId;`,
          {
            replacements: { targetOutletId },
            type: QueryTypes.SELECT,
          }
        );
        backupData[child.name] = rows || [];
        totalRecords += (rows || []).length;
      } catch (_) {
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
    const checksum = crypto.createHash('sha256').update(jsonString).digest('hex');
    (payload as any).checksum = checksum;

    // Compress with Gzip
    const compressedBuffer = zlib.gzipSync(Buffer.from(JSON.stringify(payload), 'utf8'));

    const now = new Date();
    const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}-${String(now.getMinutes()).padStart(2, '0')}-${String(now.getSeconds()).padStart(2, '0')}`;
    const filename = `tenant_backup_${outletCode || `OUT${targetOutletId}`}_${timestamp}.posbak`;
    const filePath = path.join(outletDir, filename);

    // Also place a symlink/copy in main backups folder for unified management
    const rootBackupPath = path.join(BACKUP_BASE_DIR, filename);

    await fsPromises.writeFile(filePath, compressedBuffer);
    try {
      await fsPromises.copyFile(filePath, rootBackupPath);
    } catch (_) {}

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
  public static async restoreTenantBackup(
    activeDb: any,
    targetOutletId: number,
    fileBuffer: Buffer,
    options: { overwriteExisting?: boolean } = {}
  ): Promise<{ success: boolean; totalRecordsRestored: number; tablesRestored: string[]; outletId: number }> {
    const destOutletId = Number(targetOutletId);
    if (!destOutletId) throw new Error('Valid target outlet ID is required for restore.');

    // Decompress payload
    let jsonText: string;
    try {
      const decompressed = zlib.gunzipSync(fileBuffer);
      jsonText = decompressed.toString('utf8');
    } catch (e) {
      // If not gzipped, try raw utf8
      jsonText = fileBuffer.toString('utf8');
    }

    let payload: any;
    try {
      payload = JSON.parse(jsonText);
    } catch (e: any) {
      throw new Error(`Invalid backup file format: ${e.message}`);
    }

    if (payload.format !== 'FAMALTH_POS_TENANT_BACKUP_V2' && !payload.tables) {
      throw new Error('Unrecognized backup format. Please supply a valid .posbak file.');
    }

    const tables = payload.tables || {};
    const tableKeys = Object.keys(tables);
    let totalRecordsRestored = 0;
    const tablesRestored: string[] = [];

    // Cache valid table columns and types from information_schema
    const colMap = new Map<string, Map<string, string>>();
    try {
      const [tableCols]: any = await activeDb.query(`
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
      `);
      for (const c of tableCols) {
        if (!colMap.has(c.table_name)) colMap.set(c.table_name, new Map());
        colMap.get(c.table_name)!.set(c.column_name, c.data_type);
      }
    } catch (schemaErr: any) {
      console.warn('⚠️ Could not query information_schema for backup restore validation:', schemaErr.message);
    }

    // Execute restore inside transaction to ensure atomicity
    await activeDb.transaction(async (t: any) => {
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
            await activeDb.query(q, { replacements: { destOutletId }, transaction: t }).catch(() => {});
          } catch (_) {}
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
        if (!Array.isArray(rows) || rows.length === 0) continue;
        const validColMap = colMap.get(tbl);
        if (colMap.size > 0 && !validColMap) continue;

        for (const row of rows) {
          const rowCopy = { ...row };
          // STRICT OUTLET REMAPPING: Force row to destination outlet
          if ('outlet_id' in rowCopy) {
            rowCopy.outlet_id = destOutletId;
          }

          // Filter row properties to only columns that physically exist in the database table
          const cols = Object.keys(rowCopy).filter((c) => !validColMap || validColMap.has(c));
          if (cols.length === 0) continue;

          const colList = cols.map((c) => `"${c}"`).join(', ');
          const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
          const values = cols.map((c) => {
            const val = rowCopy[c];
            const dtype = validColMap ? validColMap.get(c) : null;
            if (val !== null && typeof val === 'object' && !(val instanceof Date) && !Buffer.isBuffer(val)) {
              return JSON.stringify(val);
            }
            if (dtype === 'json' || dtype === 'jsonb') {
              if (typeof val === 'string') return val;
              return JSON.stringify(val);
            }
            return val;
          });

          try {
            await activeDb.query(
              `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`,
              { bind: values, transaction: t }
            );
            totalRecordsRestored++;
          } catch (rowErr: any) {
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
      } catch (_) {}
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
  public static resolveBackupFilePath(filename: string, outletCode?: string, isSuperAdmin: boolean = false): string | null {
    const sanitized = path.basename(filename);
    const searchRoots = getBackupSearchRoots();

    for (const root of searchRoots) {
      const entCandidate = path.join(root, 'enterprise', sanitized);
      if (fs.existsSync(entCandidate)) return entCandidate;
      if (outletCode) {
        const outletPath = path.join(root, 'outlets', outletCode, sanitized);
        if (fs.existsSync(outletPath)) return outletPath;
      }

      const rootCandidate = path.join(root, sanitized);
      if (fs.existsSync(rootCandidate)) {
        if (!isSuperAdmin && outletCode) {
          if (sanitized.includes(outletCode)) return rootCandidate;
        } else {
          return rootCandidate;
        }
      }

      // Check subdirectories in outlets/
      const outletsDir = path.join(root, 'outlets');
      if (fs.existsSync(outletsDir)) {
        try {
          const subdirs = fs.readdirSync(outletsDir);
          for (const sub of subdirs) {
            if (!isSuperAdmin && outletCode && sub !== outletCode) continue;
            const cand = path.join(outletsDir, sub, sanitized);
            if (fs.existsSync(cand)) return cand;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /**
   * 5. Delete Backup File
   */
  public static async deleteBackup(filename: string, outletCode?: string, isSuperAdmin: boolean = false): Promise<{ success: boolean; message?: string }> {
    const filePath = this.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
    if (!filePath) {
      return { success: false, message: 'Backup snapshot not found on disk or permission denied.' };
    }

    if (!isSuperAdmin && outletCode) {
      const isAllowed = filePath.includes(path.join('outlets', outletCode)) || filename.includes(outletCode);
      if (!isAllowed) {
        return { success: false, message: 'Access denied: You can only delete your own outlet backups.' };
      }
    }

    try {
      await fsPromises.unlink(filePath);
      return { success: true };
    } catch (err: any) {
      return { success: false, message: err.message || 'File deletion failed.' };
    }
  }

  /**
   * 6. Generate Complete Full-System Data Backup
   * Backs up all outlets, global configurations, and schemas into a signed system archive.
   */
  public static async createSystemBackup(activeDb: any): Promise<{ filename: string; filePath: string; totalRecords: number; sizeBytes: number; checksum: string }> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const filename = `system_full_backup_${timestamp}.posbak`;
    const filePath = path.join(BACKUP_BASE_DIR, filename);

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

    const exportPayload: Record<string, any[]> = {};
    let totalRecords = 0;

    for (const tbl of allTables) {
      try {
        const rows: any = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: QueryTypes.SELECT }).catch(() => []);
        const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
        exportPayload[tbl] = rowList;
        totalRecords += rowList.length;
      } catch (_) {
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
    const compressedBuffer = zlib.gzipSync(Buffer.from(jsonString, 'utf8'), { level: 9 });
    const checksum = crypto.createHash('sha256').update(compressedBuffer).digest('hex');

    await fsPromises.mkdir(BACKUP_BASE_DIR, { recursive: true });
    await fsPromises.writeFile(filePath, compressedBuffer);

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
  public static async restoreSystemBackup(activeDb: any, fileBuffer: Buffer): Promise<{ success: boolean; totalRecordsRestored: number; tablesRestored: string[] }> {
    let jsonText: string;
    try {
      jsonText = zlib.gunzipSync(fileBuffer).toString('utf8');
    } catch {
      jsonText = fileBuffer.toString('utf8');
    }

    const payload = JSON.parse(jsonText);
    const tables = payload.tables || {};
    let totalRecordsRestored = 0;
    const tablesRestored: string[] = [];

    await activeDb.transaction(async (t: any) => {
      for (const [tbl, rows] of Object.entries(tables)) {
        if (!Array.isArray(rows) || rows.length === 0) continue;
        for (const row of rows as any[]) {
          const cols = Object.keys(row);
          const colList = cols.map((c) => `"${c}"`).join(', ');
          const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
          const values = Object.values(row);

          try {
            await activeDb.query(
              `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`,
              { bind: values, transaction: t }
            );
            totalRecordsRestored++;
          } catch (_) {}
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
  public static async createEnterpriseZipBackup(
    activeDb: any,
    includeUploads: boolean = true
  ): Promise<{ filename: string; filePath: string; totalRecords: number; sizeBytes: number; downloadUrl: string }> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const filename = `famalth-enterprise-backup-${timestamp}.zip`;
    const filePath = path.join(BACKUP_BASE_DIR, filename);

    await fsPromises.mkdir(BACKUP_BASE_DIR, { recursive: true });

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

    const exportPayload: Record<string, any[]> = {};
    let totalRecords = 0;
    let sqlScript = `-- FAMALTH ENTERPRISE POSTGRESQL COMPLETE DUMP\n-- Generated: ${new Date().toISOString()}\n\nBEGIN;\n`;

    for (const tbl of allTables) {
      try {
        const rows: any = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: QueryTypes.SELECT }).catch(() => []);
        const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
        exportPayload[tbl] = rowList;
        totalRecords += rowList.length;

        if (rowList.length > 0) {
          sqlScript += `\n-- Table: ${tbl} (${rowList.length} rows)\n`;
          for (const row of rowList) {
            const cols = Object.keys(row).map(c => `"${c}"`).join(', ');
            const vals = Object.values(row).map(v => {
              if (v === null || v === undefined) return 'NULL';
              if (typeof v === 'number' || typeof v === 'boolean') return v;
              if (typeof v === 'object') return `'${JSON.stringify(v).replace(/'/g, "''")}'`;
              return `'${String(v).replace(/'/g, "''")}'`;
            }).join(', ');
            sqlScript += `INSERT INTO "${tbl}" (${cols}) VALUES (${vals}) ON CONFLICT DO NOTHING;\n`;
          }
        }
      } catch (_) {
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
    await new Promise<void>((resolve, reject) => {
      const output = fs.createWriteStream(filePath);
      const archive = archiver('zip', {
        zlib: { level: 9 },
      });

      output.on('close', () => resolve());
      archive.on('error', (err: any) => reject(err));

      archive.pipe(output);

      // 1. Add manifest.json
      archive.append(JSON.stringify(manifest, null, 2), { name: 'manifest.json' });

      // 2. Add database.json
      archive.append(JSON.stringify({ manifest, tables: exportPayload }, null, 2), { name: 'database.json' });

      // 3. Add database.sql
      archive.append(sqlScript, { name: 'database.sql' });

      // 4. Add uploads directory if requested and exists
      if (includeUploads) {
        const uploadsDir = path.join(canonicalRootDir, 'uploads');
        if (fs.existsSync(uploadsDir)) {
          archive.directory(uploadsDir, 'uploads');
        }
        const backendUploadsDir = path.join(canonicalRootDir, 'backend', 'uploads');
        if (fs.existsSync(backendUploadsDir)) {
          archive.directory(backendUploadsDir, 'backend_uploads');
        }
      }

      archive.finalize();
    });

    const stat = await fsPromises.stat(filePath);

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
  public static async restoreEnterpriseZipBackup(
    activeDb: any,
    fileBuffer: Buffer,
    filename: string
  ): Promise<{ success: boolean; totalRecordsRestored: number; tablesRestored: string[]; uploadsRestored: boolean }> {
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
      } else if (file.path.startsWith('uploads/')) {
        const relPath = file.path;
        const destPath = path.join(canonicalRootDir, relPath);
        if (file.type === 'Directory') {
          await fsPromises.mkdir(destPath, { recursive: true });
        } else {
          await fsPromises.mkdir(path.dirname(destPath), { recursive: true });
          const content = await file.buffer();
          await fsPromises.writeFile(destPath, content);
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
    const tablesRestored: string[] = [];

    await activeDb.transaction(async (t: any) => {
      for (const [tbl, rows] of Object.entries(tables)) {
        if (!Array.isArray(rows) || rows.length === 0) continue;
        for (const row of rows as any[]) {
          const cols = Object.keys(row);
          const colList = cols.map((c) => `"${c}"`).join(', ');
          const valPlaceholders = cols.map((_, idx) => `$${idx + 1}`).join(', ');
          const values = Object.values(row);

          try {
            await activeDb.query(
              `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`,
              { bind: values, transaction: t }
            );
            totalRecordsRestored++;
          } catch (_) {}
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
      } catch (_) {}
    });

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
  public static async createFambakBackup(
    activeDb: any,
    options: {
      scope: 'ALL' | 'OUTLET';
      outletId?: number;
      outletCode?: string;
      outletMeta?: any;
      saveToDrive?: boolean;
    }
  ): Promise<{
    filename: string;
    filePath: string;
    sizeBytes: number;
    sizePretty: string;
    totalRecords: number;
    scope: 'ALL' | 'OUTLET';
    outlets: any[];
    downloadUrl: string;
    driveStatus?: { success: boolean; message: string; fileId?: string };
    s3Status?: boolean;
  }> {
    const isAll = options.scope === 'ALL';
    const now = new Date();
    const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}-${String(now.getMinutes()).padStart(2, '0')}-${String(now.getSeconds()).padStart(2, '0')}`;

    const tablesToExport = [
      'outlets', 'users', 'system_settings', 'app_branding', 'tax_groups', 'tax_group_components',
      'item_groups', 'subcategories', 'brands', 'item_master', 'batches', 'stock_locations',
      'stock_ledger', 'item_modifiers', 'item_boms', 'customers', 'customer_advances', 'customer_repayments',
      'sales_headers', 'sales_items', 'restaurant_tables', 'table_reservations', 'kot_headers', 'kot_items',
      'purchase_orders', 'purchase_order_items', 'goods_receipts', 'goods_receipt_items', 'supplier_master',
      'supplier_bills', 'supplier_payments', 'clinic_appointments', 'hr_employees', 'hr_attendance_punches',
      'hr_biometric_devices', 'expenses', 'accounting_vouchers', 'voucher_lines', 'bank_accounts', 'cash_ledger',
      'milk_subscriptions', 'milk_subscription_consumptions', 'milk_subscription_items', 'user_notes',
      'numbering_settings', 'paymentMethod', 'saleSource'
    ];

    const backupData: Record<string, any[]> = {};
    let totalRecords = 0;
    const outletsList: any[] = [];
    let filename = '';
    let targetDirectory = '';

    if (isAll) {
      targetDirectory = path.join(BACKUP_BASE_DIR, 'enterprise');
      await fsPromises.mkdir(targetDirectory, { recursive: true });
      filename = `enterprise_backup_all_${timestamp}.fambak`;

      // Read all records for each table
      for (const tbl of tablesToExport) {
        try {
          const rows: any[] = await activeDb.query(`SELECT * FROM "${tbl}";`, { type: QueryTypes.SELECT }).catch(() => []);
          const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
          backupData[tbl] = rowList;
          totalRecords += rowList.length;
        } catch (_) {
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
            if (tName === 'outlets' || !Array.isArray(rows)) continue;
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
      } else {
        outletsList.push({
          id: 1,
          code: 'DEFAULT',
          name: 'Primary Enterprise Store',
          business_module: 'ALL',
          recordCount: totalRecords,
        });
      }
    } else {
      // Scoped Single Outlet
      const outletId = Number(options.outletId || 1);
      const outletCode = String(options.outletCode || `OUT_${outletId}`);
      targetDirectory = path.join(BACKUP_BASE_DIR, 'outlets', outletCode);
      await fsPromises.mkdir(targetDirectory, { recursive: true });
      filename = `outlet_backup_${outletCode}_${timestamp}.fambak`;

      const outletScopedTables = [
        'item_master', 'batches', 'stock_locations', 'stock_ledger', 'item_modifiers', 'item_boms',
        'customers', 'customer_advances', 'customer_repayments', 'sales_headers', 'restaurant_tables',
        'table_reservations', 'kot_headers', 'purchase_orders', 'goods_receipts', 'supplier_master',
        'supplier_bills', 'supplier_payments', 'clinic_appointments', 'hr_employees', 'hr_attendance_punches',
        'hr_biometric_devices', 'expenses', 'accounting_vouchers', 'bank_accounts', 'cash_ledger',
        'milk_subscriptions', 'milk_subscription_consumptions', 'user_notes', 'numbering_settings'
      ];

      for (const tbl of outletScopedTables) {
        try {
          const rows: any[] = await activeDb.query(
            `SELECT * FROM "${tbl}" WHERE outlet_id = :targetOutletId;`,
            { replacements: { targetOutletId: outletId }, type: QueryTypes.SELECT }
          ).catch(() => []);
          const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
          backupData[tbl] = rowList;
          totalRecords += rowList.length;
        } catch (_) {
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
      ];

      for (const child of childTables) {
        try {
          const rows: any[] = await activeDb.query(
            `SELECT c.* FROM "${child.name}" c 
             JOIN "${child.parentTable}" p ON c."${child.fk}" = p.id 
             WHERE p.outlet_id = :targetOutletId;`,
            { replacements: { targetOutletId: outletId }, type: QueryTypes.SELECT }
          ).catch(() => []);
          const rowList = Array.isArray(rows) ? rows : (rows?.[0] || []);
          backupData[child.name] = rowList;
          totalRecords += rowList.length;
        } catch (_) {
          backupData[child.name] = [];
        }
      }

      // Scoped users & global references
      try {
        const usersRows: any[] = await activeDb.query(
          `SELECT * FROM "users" WHERE outlet_id = :targetOutletId OR outlet_code = :outletCode;`,
          { replacements: { targetOutletId: outletId, outletCode }, type: QueryTypes.SELECT }
        ).catch(() => []);
        backupData['users'] = Array.isArray(usersRows) ? usersRows : (usersRows?.[0] || []);
        totalRecords += backupData['users'].length;
      } catch (_) { backupData['users'] = []; }

      const refTables = ['system_settings', 'app_branding', 'tax_groups', 'tax_group_components', 'item_groups', 'subcategories', 'brands', 'paymentMethod', 'saleSource'];
      for (const rt of refTables) {
        try {
          const rows: any[] = await activeDb.query(`SELECT * FROM "${rt}";`, { type: QueryTypes.SELECT }).catch(() => []);
          backupData[rt] = Array.isArray(rows) ? rows : (rows?.[0] || []);
        } catch (_) { backupData[rt] = []; }
      }

      // Read outlet record
      let outletRec: any = null;
      try {
        const [oRows]: any = await activeDb.query(
          `SELECT * FROM outlets WHERE id = :outletId OR outlet_code = :outletCode LIMIT 1;`,
          { replacements: { outletId, outletCode }, type: QueryTypes.SELECT }
        ).catch(() => []);
        outletRec = oRows;
      } catch (_) {}

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
    const compressedBuffer = zlib.gzipSync(Buffer.from(jsonString, 'utf8'), { level: 9 });
    const filePath = path.join(targetDirectory, filename);
    await fsPromises.writeFile(filePath, compressedBuffer);

    // Also place in root BACKUP_BASE_DIR for quick access
    const rootPath = path.join(BACKUP_BASE_DIR, filename);
    try {
      await fsPromises.copyFile(filePath, rootPath);
    } catch (_) {}

    let driveStatus: { success: boolean; message: string; fileId?: string } | undefined;
    if (options.saveToDrive) {
      try {
        const { uploadFambakToDrive } = require('../modules/driveService');
        driveStatus = await uploadFambakToDrive(filePath, filename, isAll ? 'ALL' : (options.outletCode || 'DEFAULT'));
      } catch (dErr: any) {
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
  public static async inspectBackupManifest(fileBuffer: Buffer): Promise<{
    format: string;
    version: string;
    scope: 'ALL' | 'OUTLET';
    exportedAt: string;
    sourceOutletCode: string;
    totalRecords: number;
    outlets: { id: number; code: string; name: string; business_module: string; recordCount: number }[];
    tables: { name: string; count: number }[];
  }> {
    let jsonText = '';

    if (fileBuffer.length >= 2 && fileBuffer[0] === 0x1f && fileBuffer[1] === 0x8b) {
      jsonText = zlib.gunzipSync(fileBuffer).toString('utf8');
    } else if (fileBuffer.length >= 4 && fileBuffer[0] === 0x50 && fileBuffer[1] === 0x4B) {
      const unzipper = require('unzipper');
      const directory = await unzipper.Open.buffer(fileBuffer);
      for (const f of directory.files) {
        if (f.path === 'database.json' || f.path === 'manifest.json') {
          jsonText = (await f.buffer()).toString('utf8');
          break;
        }
      }
    } else {
      jsonText = fileBuffer.toString('utf8');
    }

    let payload: any;
    try {
      payload = JSON.parse(jsonText);
    } catch (e: any) {
      throw new Error(`Invalid or corrupted backup archive: ${e.message}`);
    }

    const tables = payload.tables || {};
    const tableSummaries: { name: string; count: number }[] = [];
    let calculatedTotal = 0;

    for (const [tName, rows] of Object.entries(tables)) {
      if (Array.isArray(rows)) {
        tableSummaries.push({ name: tName, count: rows.length });
        calculatedTotal += rows.length;
      }
    }

    let outlets: any[] = payload.outlets || [];
    if (!Array.isArray(outlets) || outlets.length === 0) {
      if (tables.outlets && Array.isArray(tables.outlets) && tables.outlets.length > 0) {
        outlets = tables.outlets.map((o: any) => ({
          id: o.id || 1,
          code: o.outlet_code || `OUT_${o.id || 1}`,
          name: o.outlet_name || o.name || `Outlet #${o.id || 1}`,
          business_module: o.business_module || 'ALL',
          recordCount: calculatedTotal,
        }));
      } else if (payload.sourceOutletId || payload.outletCode || payload.sourceOutletCode) {
        outlets = [{
          id: payload.sourceOutletId || 1,
          code: payload.sourceOutletCode || payload.outletCode || 'DEFAULT',
          name: payload.outletMeta?.name || 'Store',
          business_module: payload.outletMeta?.business_module || 'ALL',
          recordCount: calculatedTotal,
        }];
      }
    }

    const scope: 'ALL' | 'OUTLET' = payload.scope === 'ALL' || (outlets.length > 1) ? 'ALL' : 'OUTLET';

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
  public static async restoreFambakBackup(
    activeDb: any,
    fileBuffer: Buffer,
    options: {
      scope?: 'ALL' | 'OUTLET';
      selectedOutletCode?: string;
      targetOutletId?: number;
      targetOutletCode?: string;
      overwriteExisting?: boolean;
    } = {}
  ): Promise<{
    success: boolean;
    totalRecordsRestored: number;
    tablesRestored: string[];
    restoredOutletCode: string;
    targetOutletId: number | null;
  }> {
    const manifest = await this.inspectBackupManifest(fileBuffer);

    let jsonText = '';
    if (fileBuffer.length >= 2 && fileBuffer[0] === 0x1f && fileBuffer[1] === 0x8b) {
      jsonText = zlib.gunzipSync(fileBuffer).toString('utf8');
    } else if (fileBuffer.length >= 4 && fileBuffer[0] === 0x50 && fileBuffer[1] === 0x4B) {
      const unzipper = require('unzipper');
      const directory = await unzipper.Open.buffer(fileBuffer);
      for (const f of directory.files) {
        if (f.path === 'database.json') {
          jsonText = (await f.buffer()).toString('utf8');
          break;
        }
      }
    } else {
      jsonText = fileBuffer.toString('utf8');
    }

    const payload = JSON.parse(jsonText);
    const tables = payload.tables || {};
    let totalRecordsRestored = 0;
    const tablesRestored: string[] = [];

    const colMap = new Map<string, Map<string, string>>();
    try {
      const [tableCols]: any = await activeDb.query(`
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
      `);
      for (const c of tableCols) {
        if (!colMap.has(c.table_name)) colMap.set(c.table_name, new Map());
        colMap.get(c.table_name)!.set(c.column_name, c.data_type);
      }
    } catch (_) {}

    const isSelectiveOutlet = Boolean(options.selectedOutletCode) || options.scope === 'OUTLET' || manifest.scope === 'OUTLET';

    if (isSelectiveOutlet) {
      const selectedCode = (options.selectedOutletCode || manifest.sourceOutletCode || (manifest.outlets[0]?.code) || '').trim();
      const matchedOutlet = manifest.outlets.find(o => String(o.code).toLowerCase() === selectedCode.toLowerCase()) || manifest.outlets[0];
      const sourceOutletId = matchedOutlet ? Number(matchedOutlet.id) : Number(manifest.outlets[0]?.id || 1);

      const destOutletId = Number(options.targetOutletId || sourceOutletId || 1);
      const destOutletCode = String(options.targetOutletCode || selectedCode || `OUT_${destOutletId}`);

      await activeDb.transaction(async (t: any) => {
        const [existingOutlet]: any = await activeDb.query(
          `SELECT id, outlet_code FROM outlets WHERE id = :destOutletId OR outlet_code = :destOutletCode LIMIT 1;`,
          { replacements: { destOutletId, destOutletCode }, type: QueryTypes.SELECT, transaction: t }
        ).catch(() => []);

        if (!existingOutlet) {
          await activeDb.query(
            `INSERT INTO outlets (id, outlet_code, outlet_name, business_module, created_at, updated_at)
             VALUES (:destOutletId, :destOutletCode, :name, :bizModule, NOW(), NOW())
             ON CONFLICT (id) DO UPDATE SET outlet_code = :destOutletCode;`,
            {
              replacements: {
                destOutletId,
                destOutletCode,
                name: matchedOutlet?.name || `Outlet ${destOutletCode}`,
                bizModule: matchedOutlet?.business_module || 'ALL',
              },
              transaction: t,
            }
          ).catch(() => {});
        }

        if (options.overwriteExisting) {
          const childDeletes = [
            `DELETE FROM "sales_items" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "kot_items" WHERE kot_header_id IN (SELECT id FROM "kot_headers" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "purchase_order_items" WHERE po_id IN (SELECT id FROM "purchase_orders" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "goods_receipt_items" WHERE grn_id IN (SELECT id FROM "goods_receipts" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "voucher_lines" WHERE voucher_id IN (SELECT id FROM "accounting_vouchers" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "milk_subscription_items" WHERE subscription_id IN (SELECT id FROM "milk_subscriptions" WHERE outlet_id = :destOutletId)`,
            `DELETE FROM "sales_headers" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "kot_headers" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "purchase_orders" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "goods_receipts" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "stock_ledger" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "batches" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "stock_locations" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "customers" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "customer_advances" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "customer_repayments" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "supplier_bills" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "supplier_payments" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "expenses" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "accounting_vouchers" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "cash_ledger" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "clinic_appointments" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "hr_attendance_punches" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "hr_employees" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "restaurant_tables" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "milk_subscriptions" WHERE outlet_id = :destOutletId`,
            `DELETE FROM "user_notes" WHERE outlet_id = :destOutletId`
          ];
          for (const q of childDeletes) {
            try { await activeDb.query(q, { replacements: { destOutletId }, transaction: t }).catch(() => {}); } catch (_) {}
          }
        }

        const restoreOrder = [
          'tax_groups', 'tax_group_components', 'item_groups', 'subcategories', 'brands',
          'system_settings', 'app_branding', 'paymentMethod', 'saleSource', 'numbering_settings',
          'stock_locations', 'batches', 'item_master', 'item_modifiers', 'item_boms',
          'customers', 'customer_advances', 'customer_repayments',
          'supplier_master', 'supplier_bills', 'supplier_payments',
          'sales_headers', 'sales_items', 'restaurant_tables', 'table_reservations',
          'kot_headers', 'kot_items', 'purchase_orders', 'purchase_order_items',
          'goods_receipts', 'goods_receipt_items', 'clinic_appointments',
          'hr_employees', 'hr_attendance_punches', 'hr_biometric_devices',
          'expenses', 'accounting_vouchers', 'voucher_lines', 'bank_accounts', 'cash_ledger',
          'stock_ledger', 'milk_subscriptions', 'milk_subscription_consumptions', 'milk_subscription_items',
          'user_notes', 'users'
        ];

        for (const tbl of restoreOrder) {
          const rawRows = tables[tbl];
          if (!Array.isArray(rawRows) || rawRows.length === 0) continue;
          const validColMap = colMap.get(tbl);
          if (colMap.size > 0 && !validColMap) continue;

          // Filter rows for this specific outlet
          const scopedRows = rawRows.filter(row => {
            if (!row || typeof row !== 'object') return false;
            if ('outlet_id' in row) return Number(row.outlet_id) === sourceOutletId;
            if ('outlet_code' in row) return String(row.outlet_code).toLowerCase() === selectedCode.toLowerCase();
            return true; // Global master table rows included
          });

          if (scopedRows.length === 0) continue;

          for (const row of scopedRows) {
            const rowCopy = { ...row };
            if ('outlet_id' in rowCopy) rowCopy.outlet_id = destOutletId;
            if ('outlet_code' in rowCopy) rowCopy.outlet_code = destOutletCode;

            const cols = Object.keys(rowCopy).filter(c => !validColMap || validColMap.has(c));
            if (cols.length === 0) continue;

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

            try {
              await activeDb.query(
                `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`,
                { bind: values, transaction: t }
              );
              totalRecordsRestored++;
            } catch (_) {}
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
        } catch (_) {}
      });

      return {
        success: true,
        totalRecordsRestored,
        tablesRestored,
        restoredOutletCode: destOutletCode,
        targetOutletId: destOutletId,
      };
    } else {
      // Full Enterprise Restore
      await activeDb.transaction(async (t: any) => {
        for (const [tbl, rows] of Object.entries(tables)) {
          if (!Array.isArray(rows) || rows.length === 0) continue;
          const validColMap = colMap.get(tbl);
          if (colMap.size > 0 && !validColMap) continue;

          for (const row of rows as any[]) {
            const cols = Object.keys(row).filter(c => !validColMap || validColMap.has(c));
            if (cols.length === 0) continue;

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

            try {
              await activeDb.query(
                `INSERT INTO "${tbl}" (${colList}) VALUES (${valPlaceholders}) ON CONFLICT DO NOTHING;`,
                { bind: values, transaction: t }
              );
              totalRecordsRestored++;
            } catch (_) {}
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
        } catch (_) {}
      });

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
  public static async listCloudSnapshots(
    outletCode?: string,
    isSuperAdmin: boolean = false
  ): Promise<any[]> {
    const searchRoots = getBackupSearchRoots();
    const allowed = ['.fambak', '.posbak', '.enc', '.zip'];
    const collected: any[] = [];
    const seenFiles = new Set<string>();

    for (const root of searchRoots) {
      const allFiles = await getDirectorySizeAndFiles(root, allowed);
      for (const f of allFiles.files) {
        if (seenFiles.has(f.name)) continue;
        seenFiles.add(f.name);

        const isEnterprise = f.name.includes('all') || f.name.includes('enterprise') || f.name.includes('system_full');
        let fileOutlet = 'ALL';
        if (!isEnterprise) {
          const match = f.name.match(/(?:outlet_backup|tenant_backup)_([^_]+)_/);
          if (match && match[1]) fileOutlet = match[1];
        }

        if (!isSuperAdmin && outletCode && outletCode !== 'ALL' && !isEnterprise && fileOutlet !== outletCode) {
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

export default TenantBackupService;
