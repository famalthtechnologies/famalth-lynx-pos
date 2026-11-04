#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import https from 'https';
import http from 'http';
import zlib from 'zlib';
import crypto from 'crypto';
import dotenv from 'dotenv';
import { Sequelize, QueryTypes } from 'sequelize';

// Load environment from current working directory or backend root
const rootDir = process.cwd();
dotenv.config({ path: path.join(rootDir, '.env') });
dotenv.config({ path: path.join(__dirname, '.env') });
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const loadConfig = require('./utils/decryptConfig');
import TenantBackupService from './services/tenantBackup.service';
import DataRetentionService from './services/dataRetention.service';

/**
 * Initialize standalone database connection for emergency CLI operations
 */
async function getDatabaseConnection(): Promise<Sequelize> {
  let dbUrl = process.env.DATABASE_URL;
  if (dbUrl) {
    const useSSL = process.env.DB_SSL !== 'false';
    const sequelize = new Sequelize(dbUrl, {
      dialect: 'postgres',
      logging: false,
      dialectOptions: useSSL
        ? { ssl: { require: true, rejectUnauthorized: false } }
        : {},
    });
    await sequelize.authenticate();
    return sequelize;
  }

  // Fallback to config.enc or standard env
  let config: any = {};
  try {
    config = loadConfig();
  } catch (_) {}

  const dbName = config.db_database || process.env.DB_NAME || process.env.POSTGRES_DB || 'retailsale';
  const dbUser = config.db_user || process.env.DB_USER || process.env.POSTGRES_USER || 'postgres';
  const dbPass = config.db_password || process.env.DB_PASSWORD || process.env.POSTGRES_PASSWORD || '';
  const dbHost = config.db_host || process.env.DB_HOST || '127.0.0.1';
  const dbPort = Number(config.db_port || process.env.DB_PORT || 5432);

  const sequelize = new Sequelize(dbName, dbUser, dbPass, {
    host: dbHost,
    port: dbPort,
    dialect: 'postgres',
    logging: false,
    dialectOptions: process.env.DB_SSL === 'true'
      ? { ssl: { require: true, rejectUnauthorized: false } }
      : {},
  });

  await sequelize.authenticate();
  return sequelize;
}

/**
 * Download a remote backup archive into a Buffer if given a URL
 */
async function fetchBackupBuffer(source: string): Promise<Buffer> {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    console.log(`🌐 [CLI] Downloading backup snapshot from URL: ${source}...`);
    return new Promise((resolve, reject) => {
      const client = source.startsWith('https://') ? https : http;
      client.get(source, (res) => {
        if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return fetchBackupBuffer(res.headers.location).then(resolve).catch(reject);
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode} failed to download archive.`));
        }
        const chunks: Buffer[] = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          console.log(`✅ [CLI] Download completed (${(buffer.length / (1024 * 1024)).toFixed(2)} MB).`);
          resolve(buffer);
        });
        res.on('error', reject);
      }).on('error', reject);
    });
  }

  const resolved = path.resolve(source);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Backup file not found at path: ${resolved}`);
  }
  return fs.promises.readFile(resolved);
}

function printBanner(): void {
  console.log(`
╔══════════════════════════════════════════════════════════════════╗
║     🛡️  FAMALTH ENTERPRISE DISASTER RECOVERY & BACKUP CLI        ║
║         Off-Server Cloud & Offline Resilience Engine        ║
╚══════════════════════════════════════════════════════════════════╝`);
}

function printUsage(): void {
  printBanner();
  console.log(`
Usage:
  node disaster_recovery.js status
      Tests database connectivity, reports active outlets and table counts.

  node disaster_recovery.js info <path_or_url>
      Inspects backup manifest without modifying the database.

  node disaster_recovery.js restore <path_or_url> [options]
      Restores database from local file or emailed download link.
      Options:
        --outlet <code_>      Restore only this specific outlet from the archive
        --overwrite           Point-in-time rollback (cleans old tables before import)
        --targetId <id>       Remap restored records to this outlet ID
        --targetCode <code_>  Remap restored records to this outlet code

  node disaster_recovery.js backup [options]
      Creates a fresh .fambak archive directly from CLI.
      Options:
        --all                 Complete enterprise backup (all outlets) [Default]
        --outlet <code_>      Scoped backup of a specific outlet
        --drive               Upload snapshot to Google Drive
        --email <address>     Email secure 7-day download link to operator

  node disaster_recovery.js retention-preview [options]
      Dry-run preview of records matching retention criteria (e.g. 5-year policy).
      Options:
        --years <n>           Older than N years (default: 5)
        --outlet <code_>      Check specific outlet only (default: all)
        --all                 Enterprise-wide preview across all tenants
        --start <date>        Custom start date (ISO or YYYY-MM-DD)
        --end <date>          Custom end date (ISO or YYYY-MM-DD)

  node disaster_recovery.js retention-purge [options]
      Executes statutory retention pruning with automated safety backup snapshot.
      Options:
        --years <n>           Purge records older than N years (default: 5)
        --outlet <code_>      Purge specific outlet only
        --all                 Enterprise-wide purge across all tenants
        --no-backup           Skip safety backup snapshot
        --email <address>     Email safety backup link to operator

  node disaster_recovery.js help
      Prints complete DigitalOcean Droplet recovery runbook.
`);
}

async function handleStatus(): Promise<void> {
  console.log('🔍 [CLI] Testing PostgreSQL connection...');
  const db = await getDatabaseConnection();
  console.log('✅ [CLI] Database connection authenticated successfully.');

  const outlets: any[] = await db.query('SELECT id, outlet_code, outlet_name, business_module, is_active FROM outlets ORDER BY id ASC;', {
    type: QueryTypes.SELECT
  }).catch(() => []);

  console.log(`\n🏢 Configured Outlets (${outlets.length}):`);
  outlets.forEach(o => {
    console.log(`  - [#${o.id}] ${o.outlet_code} | ${o.outlet_name || 'Store'} | Module: ${o.business_module} | Active: ${o.is_active}`);
  });

  const [salesCount]: any = await db.query('SELECT COUNT(*) as count FROM sales_headers;').catch(() => [{ count: 0 }]);
  const [itemsCount]: any = await db.query('SELECT COUNT(*) as count FROM item_master;').catch(() => [{ count: 0 }]);
  const [custCount]: any = await db.query('SELECT COUNT(*) as count FROM customers;').catch(() => [{ count: 0 }]);

  console.log(`\n📊 Enterprise Statistics:`);
  console.log(`  - Total Sales Transactions: ${salesCount?.count || 0}`);
  console.log(`  - Master Catalog Items:     ${itemsCount?.count || 0}`);
  console.log(`  - Registered Customers:     ${custCount?.count || 0}`);

  await db.close();
}

async function handleInfo(source: string): Promise<void> {
  console.log(`🔍 [CLI] Inspecting archive from: ${source}...`);
  const buffer = await fetchBackupBuffer(source);
  const manifest = await TenantBackupService.inspectBackupManifest(buffer);

  console.log(`\n📦 Archive Metadata:`);
  console.log(`  - Format:             ${manifest.format} (${manifest.version})`);
  console.log(`  - Scope:              ${manifest.scope}`);
  console.log(`  - Exported At:        ${manifest.exportedAt}`);
  console.log(`  - Source Outlet Code: ${manifest.sourceOutletCode}`);
  console.log(`  - Total Records:      ${manifest.totalRecords.toLocaleString()}`);

  console.log(`\n🏢 Contained Outlets (${manifest.outlets.length}):`);
  manifest.outlets.forEach(o => {
    console.log(`  - [#${o.id}] ${o.code} | ${o.name} | Records: ${o.recordCount.toLocaleString()}`);
  });

  console.log(`\n📋 Tables Breakdown:`);
  manifest.tables.forEach(t => {
    console.log(`  - ${t.name.padEnd(30)} : ${t.count.toLocaleString()} rows`);
  });
}

async function handleRestore(args: string[]): Promise<void> {
  const source = args[0];
  if (!source) {
    console.error('❌ Error: Missing backup file path or download URL.');
    process.exit(1);
  }

  let selectedOutletCode: string | undefined;
  let targetOutletId: number | undefined;
  let targetOutletCode: string | undefined;
  let overwriteExisting = false;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--outlet' && args[i + 1]) {
      selectedOutletCode = args[i + 1];
      i++;
    } else if (args[i] === '--overwrite') {
      overwriteExisting = true;
    } else if (args[i] === '--targetId' && args[i + 1]) {
      targetOutletId = Number(args[i + 1]);
      i++;
    } else if (args[i] === '--targetCode' && args[i + 1]) {
      targetOutletCode = args[i + 1];
      i++;
    }
  }

  console.log(`📥 [CLI] Preparing restore from: ${source}`);
  const buffer = await fetchBackupBuffer(source);

  console.log('🔍 [CLI] Pre-inspecting manifest...');
  const manifest = await TenantBackupService.inspectBackupManifest(buffer);
  console.log(`ℹ️ [CLI] Detected archive scope: ${manifest.scope} (${manifest.totalRecords.toLocaleString()} records).`);

  const db = await getDatabaseConnection();

  console.log(`\n🚀 [CLI] Initiating transactional database restoration...`);
  console.log(`  - Strategy:       ${overwriteExisting ? 'Point-in-Time Rollback (Overwrite Existing)' : 'Safe Merge (Preserve Newer Records)'}`);
  if (selectedOutletCode) {
    console.log(`  - Selective Scoping: Extracting only outlet [${selectedOutletCode}]`);
  }

  const result = await TenantBackupService.restoreFambakBackup(db, buffer, {
    scope: selectedOutletCode ? 'OUTLET' : manifest.scope,
    selectedOutletCode,
    targetOutletId,
    targetOutletCode,
    overwriteExisting,
  });

  console.log(`
==================================================================
  ✅ RESTORATION COMPLETED SUCCESSFULLY
==================================================================
  - Target Outlet:     ${result.restoredOutletCode} (ID: ${result.targetOutletId})
  - Records Restored:  ${result.totalRecordsRestored.toLocaleString()}
  - Tables Restored:   ${result.tablesRestored.length} tables
  - Strategy Used:     ${overwriteExisting ? 'Point-in-Time Rollback' : 'Safe Merge'}
==================================================================
`);

  await db.close();
}


async function handleRetentionPreview(args: string[]): Promise<void> {
  let isAll = true;
  let outletCode = 'DEFAULT';
  let olderThanYears = 5;
  let startDate: string | undefined;
  let endDate: string | undefined;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--outlet' && args[i + 1]) {
      isAll = false;
      outletCode = args[i + 1];
      i++;
    } else if (args[i] === '--all') {
      isAll = true;
    } else if (args[i] === '--years' && args[i + 1]) {
      olderThanYears = Number(args[i + 1]);
      i++;
    } else if (args[i] === '--start' && args[i + 1]) {
      startDate = args[i + 1];
      i++;
    } else if (args[i] === '--end' && args[i + 1]) {
      endDate = args[i + 1];
      i++;
    }
  }

  console.log(`🔍 [CLI] Running Retention Policy Preview (${isAll ? 'Enterprise All Outlets' : `Outlet: ${outletCode}`})...`);
  const db = await getDatabaseConnection();

  let outletId = 1;
  if (!isAll) {
    const [row]: any = await db.query('SELECT id FROM outlets WHERE outlet_code = :outletCode LIMIT 1;', {
      replacements: { outletCode },
      type: QueryTypes.SELECT
    }).catch(() => []);
    if (row && row.id) outletId = Number(row.id);
  }

  const preview = await DataRetentionService.previewRetentionPurge(db, {
    allOutlets: isAll,
    outletId: isAll ? undefined : outletId,
    outletCode: isAll ? undefined : outletCode,
    retentionType: (startDate || endDate) ? 'DATE_RANGE' : 'OLDER_THAN',
    olderThanYears,
    startDate,
    endDate,
  });

  console.log(`
==================================================================
  📊 RETENTION POLICY DRY-RUN PREVIEW
==================================================================
  - Scope:             ${preview.scope}
  - Policy:            ${preview.retentionPolicy}
  - Matching Records:  ${preview.totalMatchingRecords.toLocaleString()}
==================================================================
  Breakdown by Table:`);

  preview.breakdown.forEach(b => {
    console.log(`  - [${b.module.padEnd(10)}] ${b.table.padEnd(30)}: ${b.count.toLocaleString()} rows`);
  });

  console.log(`==================================================================
`);
  await db.close();
}

async function handleRetentionPurge(args: string[]): Promise<void> {
  let isAll = false;
  let outletCode = '';
  let olderThanYears = 5;
  let startDate: string | undefined;
  let endDate: string | undefined;
  let createBackupFirst = true;
  let emailTo = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--outlet' && args[i + 1]) {
      isAll = false;
      outletCode = args[i + 1];
      i++;
    } else if (args[i] === '--all') {
      isAll = true;
    } else if (args[i] === '--years' && args[i + 1]) {
      olderThanYears = Number(args[i + 1]);
      i++;
    } else if (args[i] === '--start' && args[i + 1]) {
      startDate = args[i + 1];
      i++;
    } else if (args[i] === '--end' && args[i + 1]) {
      endDate = args[i + 1];
      i++;
    } else if (args[i] === '--no-backup') {
      createBackupFirst = false;
    } else if (args[i] === '--email' && args[i + 1]) {
      emailTo = args[i + 1];
      i++;
    }
  }

  if (!isAll && !outletCode) {
    console.error('❌ Error: Must specify either --outlet <code_> or --all for enterprise-wide purge.');
    process.exit(1);
  }

  console.log(`🚀 [CLI] Executing Retention Purge (${isAll ? 'ENTERPRISE ALL OUTLETS' : `Outlet: ${outletCode}`})...`);
  const db = await getDatabaseConnection();

  let outletId = 1;
  if (!isAll) {
    const [row]: any = await db.query('SELECT id FROM outlets WHERE outlet_code = :outletCode LIMIT 1;', {
      replacements: { outletCode },
      type: QueryTypes.SELECT
    }).catch(() => []);
    if (row && row.id) outletId = Number(row.id);
  }

  const result = await DataRetentionService.executeRetentionPurge(db, {
    allOutlets: isAll,
    outletId: isAll ? undefined : outletId,
    outletCode: isAll ? undefined : outletCode,
    retentionType: (startDate || endDate) ? 'DATE_RANGE' : 'OLDER_THAN',
    olderThanYears,
    startDate,
    endDate,
    createBackupFirst,
    recipientEmail: emailTo || undefined,
  });

  console.log(`
==================================================================
  ✅ RETENTION PURGE COMPLETED SUCCESSFULLY
==================================================================
  - Policy:            ${result.retentionPolicy}
  - Records Purged:    ${result.totalDeletedRecords.toLocaleString()}
  - Tables Affected:   ${result.tablesAffected} tables
  - Safety Backup:     ${result.backupResult ? `✅ Created (${result.backupResult.filename})` : 'Skipped (--no-backup)'}
==================================================================
`);

  await db.close();
}

async function handleBackup(args: string[]): Promise<void> {
  let isAll = true;
  let outletCode = 'DEFAULT';
  let saveToDrive = false;
  let emailTo = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--outlet' && args[i + 1]) {
      isAll = false;
      outletCode = args[i + 1];
      i++;
    } else if (args[i] === '--all') {
      isAll = true;
    } else if (args[i] === '--drive') {
      saveToDrive = true;
    } else if (args[i] === '--email' && args[i + 1]) {
      emailTo = args[i + 1];
      i++;
    }
  }

  console.log(`🚀 [CLI] Generating backup (${isAll ? 'Complete Enterprise: All Outlets' : `Outlet: ${outletCode}`})...`);
  const db = await getDatabaseConnection();

  // Find outlet ID if scoped
  let outletId = 1;
  if (!isAll) {
    const [row]: any = await db.query('SELECT id FROM outlets WHERE outlet_code = :outletCode LIMIT 1;', {
      replacements: { outletCode },
      type: QueryTypes.SELECT
    }).catch(() => []);
    if (row && row.id) outletId = Number(row.id);
  }

  const result = await TenantBackupService.createFambakBackup(db, {
    scope: isAll ? 'ALL' : 'OUTLET',
    outletId,
    outletCode,
    saveToDrive,
  });

  console.log(`
==================================================================
  ✅ BACKUP ARCHIVE CREATED SUCCESSFULLY
==================================================================
  - File:        ${result.filename}
  - Path:        ${result.filePath}
  - Size:        ${result.sizePretty} (${result.sizeBytes} bytes)
  - Records:     ${result.totalRecords.toLocaleString()}
  - Drive Sync:  ${result.driveStatus?.success ? '✅ Uploaded to Google Drive' : (result.driveStatus?.message || 'Skipped')}
  - Spaces/S3:   ${result.s3Status ? '✅ Uploaded to Cloud Object Storage' : 'Not configured'}
==================================================================
`);

  if (emailTo) {
    console.log(`📧 [CLI] Sending Off-server recovery email to ${emailTo}...`);
    try {
      const { sendMail } = require('./services/email.service');
      const jwtUtil = require('./utils/jwt.util');
      const token = jwtUtil.sign(
        { action: 'DISASTER_RECOVERY_DOWNLOAD', filename: result.filename, scope: isAll ? 'ALL' : 'OUTLET' },
        { expiresIn: '7d' }
      );
      const emailSent = await sendMail({
        db,
        outlet_id: outletId,
        to: emailTo,
        subject: `[CLI Backup] Disaster Recovery: ${result.filename}`,
        text: `Backup ready: ${result.filename} (${result.sizePretty}). Token: ${token}`,
      });
      console.log(`📧 Email status: ${emailSent ? 'Delivered successfully' : 'Failed'}`);
    } catch (err: any) {
      console.warn('⚠️ Email sending error:', err.message);
    }
  }

  await db.close();
}

function handleHelp(): void {
  printBanner();
  console.log(`
📖 DISASTER RECOVERY RUNBOOK: "WHAT IF DIGITALOCEAN DROPLET CRASHES?"
---------------------------------------------------------------------
1. THE 3-2-1 BACKUP GOLD STANDARD:
   - Copy 1: Droplet local disk (/var/data/backups/ or backend/backups/)
   - Copy 2: Off-server Cloud Object Storage (DigitalOcean Spaces / AWS S3)
   - Copy 3: Off-site Offline Operator Device (Emailed download link saved to local PC/Mac)

2. BARE-METAL RESTORE ON A FRESH SERVER (Under 2 Minutes):
   Step A: Launch a fresh Ubuntu Droplet / VPS.
   Step B: Install Node.js 18+ and PostgreSQL 14+.
   Step C: Clone repo or deploy application files. Run: npm install
   Step D: Point .env DATABASE_URL to your new PostgreSQL instance.
   Step E: Run the 1-line emergency disaster recovery command:
           node disaster_recovery.js restore /path/to/backup.fambak

3. RESTORING DIRECTLY FROM AN EMAILED SECURE DOWNLOAD LINK:
   If you have the download link from your email:
           node disaster_recovery.js restore "https://pos.yourdomain.com/api/backup/email-download?token=..."

4. RESTORING ONLY A SINGLE OUTLET INTO AN EXISTING MULTI-OUTLET SYSTEM:
           node disaster_recovery.js restore backup.fambak --outlet OUT_101
`);
}

async function main() {
  const args = process.argv.slice(2);
  const command = (args[0] || '').toLowerCase();

  try {
    switch (command) {
      case 'status':
        await handleStatus();
        break;
      case 'info':
        if (!args[1]) {
          console.error('❌ Error: Missing file path or URL for info inspection.');
          process.exit(1);
        }
        await handleInfo(args[1]);
        break;
      case 'restore':
        await handleRestore(args.slice(1));
        break;
      case 'backup':
        await handleBackup(args.slice(1));
        break;
      case 'retention-preview':
        await handleRetentionPreview(args.slice(1));
        break;
      case 'retention-purge':
        await handleRetentionPurge(args.slice(1));
        break;
      case 'help':
      case '--help':
      case '-h':
        handleHelp();
        break;
      default:
        printUsage();
        break;
    }
  } catch (err: any) {
    console.error(`\n❌ [DISASTER RECOVERY ERROR]: ${err.message || err}`);
    if (process.env.DEBUG) console.error(err.stack);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export default {
  getDatabaseConnection,
  fetchBackupBuffer,
};
