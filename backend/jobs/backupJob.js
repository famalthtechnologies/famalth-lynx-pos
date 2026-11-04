"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startBackupJob = startBackupJob;
const node_cron_1 = __importDefault(require("node-cron"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const { decryptAndUnzip } = require('../utils/decrypt');
const { processBackup } = require('../modules/backupService');
const { uploadBackupViaScript, cleanOldBackups } = require('../modules/driveService');
const { retry } = require('../utils/retry');
const { getBackupStatus, updateSyncSuccess } = require('../utils/backupTracker');
// Define strict backup and log directories
const isCompiled = typeof process.pkg !== 'undefined';
const baseDir = isCompiled ? path_1.default.dirname(process.execPath) : path_1.default.join(__dirname, '..');
const BACKUP_DIR = path_1.default.join(baseDir, 'backups');
const LOG_FILE = path_1.default.join(baseDir, 'backup-log.txt');
const activeBackupJobs = new Set();
// ==========================================
// LOGGER & EXCEPTION HANDLERS
// ==========================================
function logMessage(msg, isError = false) {
    const timestamp = new Date().toISOString();
    const level = isError ? '[ERROR]' : '[INFO]';
    const logText = `${timestamp} ${level} ${msg}\n`;
    if (isError) {
        console.error(logText.trim());
    }
    else {
        console.log(logText.trim());
    }
    try {
        fs_1.default.appendFileSync(LOG_FILE, logText);
    }
    catch (e) {
        console.error(`Failed to write to log file: ${e.message}`);
    }
}
process.on('uncaughtException', (err) => {
    logMessage(`[FATAL] Uncaught Exception: ${err.message}\n${err.stack}`, true);
    process.exit(1);
});
process.on('unhandledRejection', (reason) => {
    logMessage(`[FATAL] Unhandled Rejection: ${reason}`, true);
});
// ==========================================
// BACKUP
// ==========================================
function getReadableTimestamp() {
    const now = new Date();
    return now.getFullYear() + '-' +
        String(now.getMonth() + 1).padStart(2, '0') + '-' +
        String(now.getDate()).padStart(2, '0') + '_' +
        String(now.getHours()).padStart(2, '0') + '-' +
        String(now.getMinutes()).padStart(2, '0') + '-' +
        String(now.getSeconds()).padStart(2, '0');
}
function cleanOldLocalBackups(dir, maxKeep = 5) {
    if (!fs_1.default.existsSync(dir))
        return;
    const files = fs_1.default.readdirSync(dir)
        .filter(f => f.endsWith('.enc') || f.endsWith('.fambak') || f.endsWith('.posbak'))
        .map(f => ({
        path: path_1.default.join(dir, f),
        time: fs_1.default.statSync(path_1.default.join(dir, f)).mtime.getTime()
    }))
        .sort((a, b) => b.time - a.time);
    if (files.length > maxKeep) {
        const filesToDelete = files.slice(maxKeep);
        for (const f of filesToDelete) {
            fs_1.default.unlinkSync(f.path);
        }
        logMessage(`Cleaned ${filesToDelete.length} old local backups. Retention limit: ${maxKeep}.`);
    }
}
async function verifyLocalBackup(encFilePath) {
    const verifyDir = fs_1.default.mkdtempSync(path_1.default.join(BACKUP_DIR, "verify-"));
    const verifyZip = path_1.default.join(verifyDir, "verify.zip");
    try {
        const extractedSql = await decryptAndUnzip(encFilePath, verifyZip, verifyDir);
        if (!extractedSql || !fs_1.default.existsSync(extractedSql)) {
            throw new Error("Backup archive did not contain the expected backup.sql payload.");
        }
    }
    finally {
        if (fs_1.default.existsSync(verifyDir)) {
            fs_1.default.rmSync(verifyDir, { recursive: true, force: true });
        }
    }
}
async function startBackupJob(client, config) {
    const outletCode = client && client.outlet_code ? client.outlet_code : "unknown";
    if (activeBackupJobs.has(outletCode)) {
        logMessage(`Backup job already running for outlet [${outletCode}]. Skipping duplicate trigger.`);
        return;
    }
    const { withDistributedLock } = require('../utils/distributedLock');
    const propertyDb = require('../db/models');
    activeBackupJobs.add(outletCode);
    logMessage("Backup scheduler initialized. Running cron: 0 * * * *");
    node_cron_1.default.schedule("0 * * * *", async () => {
        await withDistributedLock(propertyDb, `backup_job_${outletCode}`, async () => {
            try {
                if (!fs_1.default.existsSync(BACKUP_DIR)) {
                    fs_1.default.mkdirSync(BACKUP_DIR, { recursive: true });
                    logMessage(`Created backup directory at: ${BACKUP_DIR}`);
                }
                logMessage("Hourly backup job started.");
                const tempFile = await retry(() => processBackup(config.db_database));
                if (!tempFile || !fs_1.default.existsSync(tempFile)) {
                    throw new Error(`Backup file missing at temporary path: ${tempFile}`);
                }
                const stats = fs_1.default.statSync(tempFile);
                const fileSizeMB = (stats.size / 1024 / 1024).toFixed(2);
                logMessage(`Backup created. File size: ${fileSizeMB} MB`);
                if (stats.size === 0)
                    throw new Error("Backup file size is 0 bytes.");
                if (Number(fileSizeMB) > 35)
                    logMessage("Warning: Backup file size exceeds 35 MB threshold.", true);
                logMessage("Verifying backup integrity before local retention and upload.");
                try {
                    await verifyLocalBackup(tempFile);
                }
                catch (verifyErr) {
                    if (fs_1.default.existsSync(tempFile)) {
                        try {
                            fs_1.default.unlinkSync(tempFile);
                        }
                        catch (e) { }
                    }
                    throw new Error(`Backup integrity verification failed: ${verifyErr.message}`);
                }
                const fileName = `backup_${getReadableTimestamp()}.enc`;
                const finalFilePath = path_1.default.join(BACKUP_DIR, fileName);
                fs_1.default.renameSync(tempFile, finalFilePath);
                const currentOutlet = outletCode;
                const status = getBackupStatus(currentOutlet);
                if (status.isCloudEnabled) {
                    logMessage(`Cloud Sync enabled for outlet [${currentOutlet}]. Initiating upload.`);
                    await uploadBackupViaScript(finalFilePath, fileName, client.folderId);
                    await cleanOldBackups(client.folderId);
                    updateSyncSuccess(currentOutlet);
                    logMessage("Cloud upload sequence completed successfully.");
                }
                else {
                    logMessage(`Cloud Sync disabled for outlet [${currentOutlet}]. Bypassing upload.`);
                }
                cleanOldLocalBackups(BACKUP_DIR, 500);
                logMessage("Hourly backup job execution finished.");
            }
            catch (err) {
                logMessage(`Backup job failed: ${err.message}`, true);
            }
            finally {
                activeBackupJobs.delete(outletCode);
            }
        });
    });
}
module.exports = { startBackupJob };
