"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BackupManagementController = void 0;
const tenantBackup_service_1 = __importDefault(require("../../services/tenantBackup.service"));
const dataRetention_service_1 = __importDefault(require("../../services/dataRetention.service"));
const storageQuota_service_1 = __importDefault(require("../../services/storageQuota.service"));
const fs_1 = __importDefault(require("fs"));
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const crypto_1 = __importDefault(require("crypto"));
const { sendMail } = require('../../services/email.service');
const jwtUtil = require('../../utils/jwt.util');
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0)
        return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}
class BackupManagementController {
    /**
     * 1. Get Enterprise Storage Analytics & Backups Status
     * GET /api/backup/storage-stats
     */
    static async getStorageStats(req, res) {
        try {
            const activeDb = req.propertyDb;
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.outlet_code ||
                req.user?.outlet_code ||
                req.outlet?.outlet_code ||
                req.outlet?.code ||
                req.query?.outlet_code ||
                'DEFAULT');
            const stats = await tenantBackup_service_1.default.getStorageStats(activeDb, outletCode, isSuperAdmin);
            try {
                const outletId = Number(req.outlet_id || req.user?.outlet_id || 1);
                const quota = await storageQuota_service_1.default.calculateTenantStorage(activeDb, outletId, outletCode);
                stats.quota = quota;
            }
            catch (_) { }
            return res.json({
                success: true,
                data: stats,
            });
        }
        catch (err) {
            console.error('getStorageStats error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to retrieve storage analytics.',
            });
        }
    }
    /**
     * Enterprise-Wide & Particular Outlet-Wise Storage Analytics
     * GET /api/backup/enterprise-storage
     */
    static async getEnterpriseStorageStats(req, res) {
        try {
            const activeDb = req.propertyDb;
            const stats = await tenantBackup_service_1.default.getEnterpriseStorageAnalytics(activeDb);
            return res.json({
                success: true,
                data: stats,
            });
        }
        catch (err) {
            console.error('getEnterpriseStorageStats error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to retrieve enterprise storage analytics.',
            });
        }
    }
    /**
     * 2. Generate a Tenant-Isolated Data Backup (.posbak)
     * POST /api/backup/tenant-backup
     */
    static async createTenantBackup(req, res) {
        try {
            const activeDb = req.propertyDb;
            const outletId = Number(req.body?.outletId || req.outlet_id || req.user?.outlet_id || 1);
            const outletCode = String(req.body?.outletCode || req.outlet_code || req.user?.outlet_code || `OUT_${outletId}`);
            const outletMeta = req.outlet || {};
            const result = await tenantBackup_service_1.default.createTenantBackup(activeDb, outletId, outletCode, outletMeta);
            return res.json({
                success: true,
                message: `Tenant backup package created successfully (${result.totalRecords} records secured).`,
                data: result,
            });
        }
        catch (err) {
            console.error('createTenantBackup error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to generate tenant backup.',
            });
        }
    }
    /**
     * 3. Download Backup File Directly
     * GET /api/backup/download/:filename
     */
    static async downloadBackup(req, res) {
        try {
            const filename = String(req.params.filename || '');
            if (!filename) {
                return res.status(400).json({ success: false, message: 'Filename required.' });
            }
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.outlet_code || req.user?.outlet_code || req.outlet?.outlet_code || req.outlet?.code || '');
            const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
            if (!filePath || !fs_1.default.existsSync(filePath)) {
                return res.status(404).json({ success: false, message: 'Backup file not found or access denied.' });
            }
            const safeFilename = path_1.default.basename(filePath);
            res.setHeader('Content-Disposition', `attachment; filename="${safeFilename}"`);
            res.setHeader('Content-Type', 'application/octet-stream');
            const fileStream = fs_1.default.createReadStream(filePath);
            return fileStream.pipe(res);
        }
        catch (err) {
            console.error('downloadBackup error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 4. Restore Tenant Backup (Safe for Cloud or Offline Servers)
     * POST /api/backup/restore-tenant-backup
     */
    static async restoreTenantBackup(req, res) {
        try {
            const activeDb = req.propertyDb;
            let targetOutletId = Number(req.body?.targetOutletId || req.outlet_id || req.user?.outlet_id || 1);
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.outlet_code || req.user?.outlet_code || req.outlet?.outlet_code || req.outlet?.code || '');
            if (!isSuperAdmin && req.user?.outlet_id) {
                targetOutletId = Number(req.user.outlet_id);
            }
            const { base64, filename, overwriteExisting } = req.body;
            let fileBuffer = null;
            if (base64) {
                fileBuffer = Buffer.from(base64, 'base64');
            }
            else if (filename) {
                const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
                if (filePath && fs_1.default.existsSync(filePath)) {
                    fileBuffer = await promises_1.default.readFile(filePath);
                }
            }
            if (!fileBuffer || fileBuffer.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'No backup payload or valid filename provided for restore.',
                });
            }
            const result = await tenantBackup_service_1.default.restoreTenantBackup(activeDb, targetOutletId, fileBuffer, { overwriteExisting: overwriteExisting === true });
            return res.json({
                success: true,
                message: overwriteExisting === true
                    ? `Rollback completed: Reverted outlet #${targetOutletId} to snapshot state (${result.totalRecordsRestored} records restored).`
                    : `Safe merge completed: Restored ${result.totalRecordsRestored} records into outlet #${targetOutletId}. Newer transactions between backup and now were safely preserved.`,
                data: result,
            });
        }
        catch (err) {
            console.error('restoreTenantBackup error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to restore tenant backup.',
            });
        }
    }
    /**
     * 5. Delete a Backup File
     * DELETE /api/backup/:filename
     */
    static async deleteBackup(req, res) {
        try {
            const filename = String(req.params.filename || '');
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.outlet_code || req.user?.outlet_code || req.outlet?.outlet_code || req.outlet?.code || '');
            const result = await tenantBackup_service_1.default.deleteBackup(filename, outletCode, isSuperAdmin);
            if (!result.success) {
                return res.status(404).json({ success: false, message: result.message || 'Backup file not found or access denied.' });
            }
            return res.json({
                success: true,
                message: `Backup ${filename} deleted successfully.`,
            });
        }
        catch (err) {
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 6. Generate Full System Backup in Professional Compressed ZIP format (Super Admin Only)
     * POST /api/backup/system-backup
     */
    static async createSystemBackup(req, res) {
        try {
            const userRole = String(req.user?.role || '').toUpperCase();
            if (userRole !== 'SUPER_ADMIN' && userRole !== 'ENTERPRISE_ADMIN') {
                return res.status(403).json({ success: false, message: 'Only Super Admins can take full system backups.' });
            }
            const activeDb = req.propertyDb;
            const includeUploads = req.body?.includeUploads !== false;
            const result = await tenantBackup_service_1.default.createEnterpriseZipBackup(activeDb, includeUploads);
            return res.json({
                success: true,
                message: `Complete enterprise system backup ZIP created (${result.totalRecords} records + uploads secured).`,
                data: result,
            });
        }
        catch (err) {
            console.error('createSystemBackup error:', err);
            return res.status(500).json({ success: false, message: err.message || 'System backup failed.' });
        }
    }
    /**
     * 7. Restore Full System Backup (.zip or .posbak) (Super Admin Only)
     * POST /api/backup/restore-system-backup
     */
    static async restoreSystemBackup(req, res) {
        try {
            const userRole = String(req.user?.role || '').toUpperCase();
            if (userRole !== 'SUPER_ADMIN' && userRole !== 'ENTERPRISE_ADMIN') {
                return res.status(403).json({ success: false, message: 'Only Super Admins can restore full system backups.' });
            }
            const activeDb = req.propertyDb;
            const { base64, filename } = req.body;
            let fileBuffer = null;
            const resolvedFilename = String(filename || 'system_backup.zip');
            if (base64) {
                fileBuffer = Buffer.from(base64, 'base64');
            }
            else if (filename) {
                const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, undefined, true);
                if (filePath && fs_1.default.existsSync(filePath)) {
                    fileBuffer = await promises_1.default.readFile(filePath);
                }
            }
            if (!fileBuffer || fileBuffer.length === 0) {
                return res.status(400).json({ success: false, message: 'No system backup payload provided.' });
            }
            const result = await tenantBackup_service_1.default.restoreEnterpriseZipBackup(activeDb, fileBuffer, resolvedFilename);
            return res.json({
                success: true,
                message: `System backup restored successfully! Restored ${result.totalRecordsRestored} records across ${result.tablesRestored.length} tables.${result.uploadsRestored ? ' Uploads unpacked.' : ''}`,
                data: result,
            });
        }
        catch (err) {
            console.error('restoreSystemBackup error:', err);
            return res.status(500).json({ success: false, message: err.message || 'System restore failed.' });
        }
    }
    /**
     * 8. Create Granular .fambak Backup (All Outlets or Particular Outlet Only)
     * POST /api/backup/create-fambak
     */
    static async createFambakBackup(req, res) {
        try {
            const activeDb = req.propertyDb;
            const ip = req.ip || req.socket?.remoteAddress || '';
            const isLoopback = ip.includes('127.0.0.1') ||
                ip === '::1' ||
                ip.includes('localhost') ||
                req.hostname === 'localhost' ||
                req.hostname === '127.0.0.1';
            const userRole = String(req.user?.role || '').toUpperCase();
            const isMasterAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            // Check if request is from a LAN Client PC (private IP not loopback)
            const isLanClient = !isLoopback && (ip.includes('192.168.') || ip.includes('10.') || ip.includes('172.'));
            if (isLanClient) {
                return res.status(403).json({
                    success: false,
                    message: 'Database backups cannot be initiated from a Client PC. Please perform backups on the Main Server PC.',
                });
            }
            const scope = (String(req.body?.scope || 'OUTLET').toUpperCase() === 'ALL') ? 'ALL' : 'OUTLET';
            // Full enterprise database backup (ALL) is restricted strictly to the Local Server PC
            if (scope === 'ALL' && (!isLoopback || !isMasterAdmin)) {
                return res.status(403).json({
                    success: false,
                    message: 'All Outlets (Enterprise DB) backups can only be created directly on the Local Server PC. Cloud servers and remote terminals are restricted to their own outlet backup.',
                });
            }
            const outletId = Number(req.body?.outletId || req.outlet_id || req.user?.outlet_id || 1);
            const outletCode = String(req.body?.outletCode || req.outlet_code || req.user?.outlet_code || `OUT_${outletId}`);
            const outletMeta = req.outlet || {};
            const saveToDrive = req.body?.saveToDrive === true || req.query?.saveToDrive === 'true';
            const result = await tenantBackup_service_1.default.createFambakBackup(activeDb, {
                scope,
                outletId,
                outletCode,
                outletMeta,
                saveToDrive,
            });
            let emailResult = null;
            const recipientEmail = String(req.body?.recipientEmail || (req.body?.sendEmailLink ? (req.user?.email || process.env.ADMIN_EMAIL) : '') || '').trim();
            if (recipientEmail && recipientEmail.includes('@')) {
                try {
                    emailResult = await BackupManagementController.sendDisasterRecoveryEmail({
                        activeDb,
                        filePath: result.filePath,
                        filename: result.filename,
                        recipientEmail,
                        outletCode,
                        outletId,
                        req,
                        scope,
                    });
                }
                catch (eErr) {
                    console.warn('Auto-email backup link failed:', eErr.message);
                }
            }
            return res.json({
                success: true,
                message: scope === 'ALL'
                    ? `Complete Enterprise backup (.fambak) secured successfully (${result.totalRecords} records across all outlets).`
                    : `Granular outlet backup (.fambak) for ${outletCode} secured successfully (${result.totalRecords} records).`,
                data: result,
            });
        }
        catch (err) {
            console.error('createFambakBackup error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to generate .fambak backup archive.',
            });
        }
    }
    /**
     * 9. Pre-Inspect Backup Manifest (.fambak, .posbak, .zip, .enc, .json)
     * POST /api/backup/inspect-backup
     */
    static async inspectBackupManifest(req, res) {
        try {
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.outlet_code || req.user?.outlet_code || req.outlet?.outlet_code || req.outlet?.code || '');
            const { base64, filename } = req.body;
            let fileBuffer = null;
            if (base64) {
                fileBuffer = Buffer.from(base64, 'base64');
            }
            else if (filename) {
                const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
                if (filePath && fs_1.default.existsSync(filePath)) {
                    fileBuffer = await promises_1.default.readFile(filePath);
                }
            }
            if (!fileBuffer || fileBuffer.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'No backup payload or valid filename provided for pre-inspection.',
                });
            }
            const manifest = await tenantBackup_service_1.default.inspectBackupManifest(fileBuffer);
            return res.json({
                success: true,
                manifest,
            });
        }
        catch (err) {
            console.error('inspectBackupManifest error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to pre-inspect backup archive manifest.',
            });
        }
    }
    /**
     * 10. Restore .fambak Backup (Selective Outlet Restore or Full Enterprise)
     * POST /api/backup/restore-fambak
     */
    static async restoreFambakBackup(req, res) {
        try {
            const activeDb = req.propertyDb;
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const ip = req.ip || req.socket?.remoteAddress || '';
            const isLoopback = ip.includes('127.0.0.1') ||
                ip === '::1' ||
                ip.includes('localhost') ||
                req.hostname === 'localhost' ||
                req.hostname === '127.0.0.1';
            const isMasterAdmin = (userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN');
            const isLocalServerSuperAdmin = isMasterAdmin && isLoopback;
            // Reject restore from a LAN Client PC
            const isLanClient = !isLoopback && (ip.includes('192.168.') || ip.includes('10.') || ip.includes('172.'));
            if (isLanClient) {
                return res.status(403).json({
                    success: false,
                    message: 'Database restoration cannot be performed from a Client PC. Please restore on the Main Server PC.',
                });
            }
            const userOutletCode = String(req.outlet_code || req.user?.outlet_code || req.outlet?.outlet_code || req.outlet?.code || '');
            const requestedScope = String(req.body?.scope || '').toUpperCase();
            if (requestedScope === 'ALL' && !isLocalServerSuperAdmin) {
                return res.status(403).json({
                    success: false,
                    message: 'Complete enterprise database restoration can only be performed directly on the Local Server PC.',
                });
            }
            const { base64, filename, scope, selectedOutletCode, targetOutletId, targetOutletCode, overwriteExisting } = req.body;
            let fileBuffer = null;
            if (base64) {
                fileBuffer = Buffer.from(base64, 'base64');
            }
            else if (filename) {
                const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, userOutletCode, isSuperAdmin);
                if (filePath && fs_1.default.existsSync(filePath)) {
                    fileBuffer = await promises_1.default.readFile(filePath);
                }
            }
            if (!fileBuffer || fileBuffer.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'No backup file payload or valid filename provided for restore.',
                });
            }
            const effectiveTargetId = Number(targetOutletId || req.outlet_id || req.user?.outlet_id || 1);
            const effectiveTargetCode = String(targetOutletCode || userOutletCode || `OUT_${effectiveTargetId}`);
            const result = await tenantBackup_service_1.default.restoreFambakBackup(activeDb, fileBuffer, {
                scope: scope ? (String(scope).toUpperCase() === 'ALL' ? 'ALL' : 'OUTLET') : undefined,
                selectedOutletCode: selectedOutletCode ? String(selectedOutletCode).trim() : undefined,
                targetOutletId: effectiveTargetId,
                targetOutletCode: effectiveTargetCode,
                overwriteExisting: overwriteExisting === true,
            });
            return res.json({
                success: true,
                message: overwriteExisting === true
                    ? `Point-in-Time Rollback completed successfully: Restored ${result.totalRecordsRestored} records into outlet ${result.restoredOutletCode}.`
                    : `Safe Merge completed successfully: Restored ${result.totalRecordsRestored} records into outlet ${result.restoredOutletCode}. Newer transactions were preserved.`,
                data: result,
            });
        }
        catch (err) {
            console.error('restoreFambakBackup error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to execute backup restoration.',
            });
        }
    }
    /**
     * 11. List Cloud & Remote Snapshots History
     * GET /api/backup/cloud-backups
     */
    static async listCloudBackups(req, res) {
        try {
            const userRole = String(req.user?.role || '').toUpperCase();
            const ip = req.ip || req.socket?.remoteAddress || '';
            const isLoopback = ip.includes('127.0.0.1') ||
                ip === '::1' ||
                ip.includes('localhost') ||
                req.hostname === 'localhost' ||
                req.hostname === '127.0.0.1';
            // Enterprise super-admin visibility only applies to local server loopback:
            const isLocalServerSuperAdmin = (userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN') && isLoopback;
            const requestedScope = String(req.query?.scope || '').toUpperCase();
            const outletCode = String(req.query?.outlet_code ||
                req.outlet_code ||
                req.user?.outlet_code ||
                req.outlet?.outlet_code ||
                req.outlet?.code ||
                '');
            // On Cloud server or remote client, always force outletCode isolation
            const targetOutlet = (isLocalServerSuperAdmin && requestedScope === 'ALL') ? 'ALL' : outletCode;
            const snapshots = await tenantBackup_service_1.default.listCloudSnapshots(targetOutlet, isLocalServerSuperAdmin);
            return res.json({
                success: true,
                data: snapshots,
            });
        }
        catch (err) {
            console.error('listCloudBackups error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to list cloud snapshots.',
            });
        }
    }
    /**
     * 12. 1-Click Restore Cloud Backup Snapshot
     * POST /api/backup/restore-cloud-backup
     */
    static async restoreCloudBackup(req, res) {
        try {
            return await BackupManagementController.restoreFambakBackup(req, res);
        }
        catch (err) {
            console.error('restoreCloudBackup error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || '1-Click cloud restore failed.',
            });
        }
    }
    /**
     * Helper: Send Off-Server Disaster Recovery Email with Signed 7-Day Download Token
     */
    static async sendDisasterRecoveryEmail(options) {
        const { activeDb, filePath, filename, recipientEmail, outletCode, outletId, req } = options;
        const stat = await promises_1.default.stat(filePath);
        const fileBuffer = await promises_1.default.readFile(filePath);
        const checksum = crypto_1.default.createHash('sha256').update(fileBuffer).digest('hex');
        const sizePretty = formatBytes(stat.size);
        let scope = options.scope || 'OUTLET';
        let totalRecords = 0;
        let outletsSummary = '';
        try {
            const manifest = await tenantBackup_service_1.default.inspectBackupManifest(fileBuffer);
            scope = manifest.scope || scope;
            totalRecords = manifest.totalRecords || 0;
            if (manifest.outlets && manifest.outlets.length > 0) {
                outletsSummary = manifest.outlets.map((o) => `${o.name} (${o.code})`).join(', ');
            }
        }
        catch (_) { }
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
        const downloadToken = jwtUtil.sign({
            action: 'DISASTER_RECOVERY_DOWNLOAD',
            filename: path_1.default.basename(filename),
            outletCode,
            scope,
            sizeBytes: stat.size,
            checksum,
        }, { expiresIn: '7d' });
        const host = req.get('host') || 'localhost:3000';
        const protocol = req.protocol || 'http';
        const downloadUrl = `${protocol}://${host}/api/backup/email-download?token=${encodeURIComponent(downloadToken)}`;
        let offsiteS3Status = false;
        let offsiteDriveStatus = null;
        try {
            const { isS3Configured, uploadBackupToS3 } = require('../../modules/s3BackupService');
            if (isS3Configured()) {
                offsiteS3Status = await uploadBackupToS3(filePath, path_1.default.basename(filename));
            }
        }
        catch (_) { }
        try {
            const { uploadFambakToDrive } = require('../../modules/driveService');
            offsiteDriveStatus = await uploadFambakToDrive(filePath, path_1.default.basename(filename), outletCode);
        }
        catch (_) { }
        const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Disaster Recovery Backup Archive</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f6f9; margin: 0; padding: 24px; color: #2d3748; }
    .card { max-width: 620px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.08); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #1e3a8a, #2563eb); padding: 32px 28px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; letter-spacing: -0.5px; }
    .header p { margin: 6px 0 0; font-size: 14px; opacity: 0.9; }
    .content { padding: 32px 28px; }
    .badge { display: inline-block; padding: 4px 10px; font-size: 12px; font-weight: 600; border-radius: 9999px; text-transform: uppercase; }
    .badge-all { background: #dbeafe; color: #1e40af; }
    .badge-outlet { background: #fef3c7; color: #92400e; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; }
    .info-table td { padding: 10px 12px; border-bottom: 1px solid #edf2f7; }
    .info-table td.label { font-weight: 600; color: #718096; width: 38%; }
    .info-table td.value { font-family: 'SFMono-Regular', Consolas, Menlo, monospace; color: #1a202c; word-break: break-all; }
    .btn-container { text-align: center; margin: 30px 0 20px; }
    .btn { display: inline-block; background: #2563eb; color: #ffffff !important; padding: 14px 32px; border-radius: 8px; font-weight: 700; text-decoration: none; font-size: 15px; box-shadow: 0 3px 8px rgba(37,99,235,0.3); }
    .instructions { background: #f8fafc; border-left: 4px solid #3b82f6; padding: 16px; border-radius: 4px; margin-top: 24px; font-size: 13px; line-height: 1.6; color: #4a5568; }
    .instructions h4 { margin: 0 0 8px; color: #1a202c; font-size: 14px; }
    .code-box { background: #1e293b; color: #38bdf8; padding: 10px 14px; border-radius: 6px; font-family: monospace; font-size: 12px; margin-top: 8px; overflow-x: auto; }
    .footer { text-align: center; padding: 20px; font-size: 12px; color: #a0aec0; border-top: 1px solid #edf2f7; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>🛡️ Disaster Recovery Backup Archive Ready</h1>
      <p>Secure Off-Server Snapshot Ready for Download</p>
    </div>
    <div class="content">
      <p>Hello Administrator,</p>
      <p>A new secure disaster recovery backup archive has been generated for your POS & ERP system. We email this direct link so you can download and preserve an independent copy on your personal computer or offline cold storage.</p>
      
      <table class="info-table">
        <tr>
          <td class="label">Scope</td>
          <td class="value"><span class="badge ${scope === 'ALL' ? 'badge-all' : 'badge-outlet'}">${scope === 'ALL' ? '🌐 Complete Enterprise (All Outlets)' : '🏪 Single Outlet Scoped'}</span></td>
        </tr>
        <tr>
          <td class="label">Archive Filename</td>
          <td class="value">${path_1.default.basename(filename)}</td>
        </tr>
        <tr>
          <td class="label">Archive Size</td>
          <td class="value">${sizePretty}</td>
        </tr>
        <tr>
          <td class="label">Secured Records</td>
          <td class="value">${totalRecords > 0 ? totalRecords.toLocaleString() : 'All Active Records'}</td>
        </tr>
        ${outletsSummary ? `<tr><td class="label">Outlets Covered</td><td class="value">${outletsSummary}</td></tr>` : ''}
        <tr>
          <td class="label">SHA-256 Checksum</td>
          <td class="value" style="font-size: 11px;">${checksum}</td>
        </tr>
        <tr>
          <td class="label">DigitalOcean Spaces / S3</td>
          <td class="value">${offsiteS3Status ? '✅ Uploaded & Redundant' : 'Not configured'}</td>
        </tr>
        <tr>
          <td class="label">Google Drive Cloud</td>
          <td class="value">${offsiteDriveStatus?.success ? '✅ Redundant Copy Stored' : (offsiteDriveStatus?.message || 'Offline / Skipped')}</td>
        </tr>
        <tr>
          <td class="label">Token Validity</td>
          <td class="value">Expires in 7 days (JWT Signed)</td>
        </tr>
      </table>

      <div class="btn-container">
        <a href="${downloadUrl}" class="btn" target="_blank">📥 Download Backup Archive (.fambak)</a>
      </div>

      <div class="instructions">
        <h4>🚨 What if your DigitalOcean droplet crashes or server is destroyed?</h4>
        <p>1. Keep this downloaded <code>${path_1.default.basename(filename)}</code> file safe on your local drive or USB backup disk.</p>
        <p>2. If your cloud droplet ever fails, launch a fresh server instance, checkout the project, and run the 1-line bare-metal recovery command:</p>
        <div class="code-box">node disaster_recovery.js restore ${path_1.default.basename(filename)}</div>
        <p style="margin-top: 8px;">Your PostgreSQL tables, transaction history, inventory, user accounts, and sequence numbers will be restored in under 2 minutes.</p>
      </div>
    </div>
    <div class="footer">
      Sent automatically by Retail POS Enterprise Disaster Recovery System.<br/>
      If you did not request this backup, please check your administrator activity logs immediately.
    </div>
  </div>
</body>
</html>
    `;
        const emailSent = await sendMail({
            db: activeDb,
            outlet_id: outletId,
            to: recipientEmail,
            subject: `[Backup Ready] Disaster Recovery Archive: ${path_1.default.basename(filename)} (${sizePretty})`,
            html: htmlContent,
        });
        return {
            success: emailSent,
            message: emailSent
                ? `Disaster recovery backup link successfully emailed to ${recipientEmail}.`
                : `Backup archive secured on disk & cloud. Note: Email delivery skipped (SMTP credentials not configured in Settings).`,
            downloadUrl,
            expiresAt,
            checksum,
        };
    }
    /**
     * 13. Off-Server Disaster Recovery: Email Backup Download Link
     * POST /api/backup/email-backup-link
     */
    static async emailBackupLink(req, res) {
        try {
            const activeDb = req.propertyDb;
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            const outletCode = String(req.body?.outletCode ||
                req.outlet_code ||
                req.user?.outlet_code ||
                req.outlet?.outlet_code ||
                'DEFAULT');
            const outletId = Number(req.body?.outletId || req.outlet_id || req.user?.outlet_id || 1);
            const filename = String(req.body?.filename || '').trim();
            const recipientEmail = String(req.body?.recipientEmail ||
                req.user?.email ||
                process.env.ADMIN_EMAIL ||
                process.env.EMAIL_USER ||
                '').trim();
            if (!filename) {
                return res.status(400).json({ success: false, message: 'Backup filename is required.' });
            }
            if (!recipientEmail || !recipientEmail.includes('@')) {
                return res.status(400).json({ success: false, message: 'Valid recipient email address is required.' });
            }
            const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, outletCode, isSuperAdmin);
            if (!filePath || !fs_1.default.existsSync(filePath)) {
                return res.status(404).json({ success: false, message: 'Backup archive file not found on server.' });
            }
            const emailResult = await BackupManagementController.sendDisasterRecoveryEmail({
                activeDb,
                filePath,
                filename,
                recipientEmail,
                outletCode,
                outletId,
                req,
                scope: req.body?.scope,
            });
            return res.json({
                success: true,
                message: emailResult.message,
                downloadUrl: emailResult.downloadUrl,
                expiresAt: emailResult.expiresAt,
                checksum: emailResult.checksum,
                emailSent: emailResult.success,
            });
        }
        catch (err) {
            console.error('emailBackupLink error:', err);
            return res.status(500).json({
                success: false,
                message: err.message || 'Failed to email backup download link.',
            });
        }
    }
    /**
     * 14. Download Backup Archive Via Signed Token (Token-Authenticated Public URL)
     * GET /api/backup/email-download?token=...
     */
    static async downloadViaEmailToken(req, res) {
        try {
            const token = String(req.query?.token || '').trim();
            if (!token) {
                return res.status(401).send(`
          <div style="font-family: sans-serif; padding: 40px; text-align: center;">
            <h2 style="color: #dc2626;">Unauthorized Access</h2>
            <p style="color: #4b5563;">Missing download token. Please use the complete link provided in your disaster recovery email.</p>
          </div>
        `);
            }
            let payload;
            try {
                payload = jwtUtil.verify(token);
            }
            catch (tokenErr) {
                return res.status(403).send(`
          <div style="font-family: sans-serif; padding: 40px; text-align: center;">
            <h2 style="color: #dc2626;">Link Expired or Invalid</h2>
            <p style="color: #4b5563;">The download token has expired or is invalid (${tokenErr.message}). Please generate a fresh backup link from your POS Settings console.</p>
          </div>
        `);
            }
            if (!payload || payload.action !== 'DISASTER_RECOVERY_DOWNLOAD' || !payload.filename) {
                return res.status(403).send(`
          <div style="font-family: sans-serif; padding: 40px; text-align: center;">
            <h2 style="color: #dc2626;">Invalid Token Payload</h2>
            <p style="color: #4b5563;">The provided token is not authorized for disaster recovery downloads.</p>
          </div>
        `);
            }
            const filename = path_1.default.basename(String(payload.filename));
            const filePath = tenantBackup_service_1.default.resolveBackupFilePath(filename, payload.outletCode, true);
            if (!filePath || !fs_1.default.existsSync(filePath)) {
                return res.status(404).send(`
          <div style="font-family: sans-serif; padding: 40px; text-align: center;">
            <h2 style="color: #dc2626;">Backup Archive Not Found</h2>
            <p style="color: #4b5563;">The requested backup file (<code>${filename}</code>) is no longer available on this server's storage disk.</p>
          </div>
        `);
            }
            const stat = await promises_1.default.stat(filePath);
            res.setHeader('Content-Type', 'application/octet-stream');
            res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
            res.setHeader('Content-Length', stat.size);
            res.setHeader('X-Disaster-Recovery-Scope', payload.scope || 'ALL');
            const readStream = fs_1.default.createReadStream(filePath);
            return readStream.pipe(res);
        }
        catch (err) {
            console.error('downloadViaEmailToken error:', err);
            return res.status(500).send(`
        <div style="font-family: sans-serif; padding: 40px; text-align: center;">
          <h2 style="color: #dc2626;">Server Error</h2>
          <p style="color: #4b5563;">An unexpected error occurred while streaming the backup archive.</p>
        </div>
      `);
        }
    }
    /**
     * 15. Provider Control Plane: Preview Cloud Data Retention Pruning
     * POST /api/backup/provider/retention-preview
     */
    static async previewProviderRetention(req, res) {
        try {
            const activeDb = req.propertyDb;
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            if (!isSuperAdmin) {
                return res.status(403).json({ success: false, message: 'Provider console access denied: Super Admin role required.' });
            }
            const allOutlets = req.body?.allOutlets === true;
            const outletCode = req.body?.outletCode;
            const outletId = req.body?.outletId ? Number(req.body.outletId) : undefined;
            const retentionType = req.body?.retentionType || (req.body?.olderThanYears ? 'OLDER_THAN' : 'ALL_TIME');
            const olderThanYears = Number(req.body?.olderThanYears || 5);
            const startDate = req.body?.startDate;
            const endDate = req.body?.endDate;
            const modules = req.body?.modules;
            const preview = await dataRetention_service_1.default.previewRetentionPurge(activeDb, {
                allOutlets,
                outletId,
                outletCode,
                retentionType,
                olderThanYears,
                startDate,
                endDate,
                modules,
            });
            return res.json({
                success: true,
                preview,
            });
        }
        catch (err) {
            console.error('previewProviderRetention error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Failed to preview provider retention.' });
        }
    }
    /**
     * 16. Provider Control Plane: Execute Cloud Data Retention Pruning
     * POST /api/backup/provider/retention-purge
     */
    static async executeProviderRetention(req, res) {
        try {
            const activeDb = req.propertyDb;
            const userRole = String(req.user?.role || '').toUpperCase();
            const isSuperAdmin = userRole === 'SUPER_ADMIN' || userRole === 'ENTERPRISE_ADMIN';
            if (!isSuperAdmin) {
                return res.status(403).json({ success: false, message: 'Provider console access denied: Super Admin role required.' });
            }
            const confirmText = String(req.body?.confirmText || '').trim().toUpperCase();
            if (confirmText !== 'PURGE CONFIRMED' && confirmText !== 'DELETE ALL DATA') {
                return res.status(400).json({ success: false, message: 'Type PURGE CONFIRMED to execute cloud retention purge.' });
            }
            const allOutlets = req.body?.allOutlets === true;
            const outletCode = req.body?.outletCode;
            const outletId = req.body?.outletId ? Number(req.body.outletId) : undefined;
            const retentionType = req.body?.retentionType || (req.body?.olderThanYears ? 'OLDER_THAN' : 'ALL_TIME');
            const olderThanYears = Number(req.body?.olderThanYears || 5);
            const startDate = req.body?.startDate;
            const endDate = req.body?.endDate;
            const modules = req.body?.modules;
            const createBackupFirst = req.body?.createBackupFirst !== false;
            const recipientEmail = req.body?.recipientEmail || req.user?.email;
            const result = await dataRetention_service_1.default.executeRetentionPurge(activeDb, {
                allOutlets,
                outletId,
                outletCode,
                retentionType,
                olderThanYears,
                startDate,
                endDate,
                modules,
                createBackupFirst,
                recipientEmail,
                req,
            });
            return res.json({
                success: true,
                message: `Provider retention purge completed: ${result.totalDeletedRecords.toLocaleString()} records removed.`,
                data: result,
            });
        }
        catch (err) {
            console.error('executeProviderRetention error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Failed to execute provider retention purge.' });
        }
    }
    /**
     * 17. Get Outlet Metered Cloud Storage Quota
     * GET /api/backup/storage-quota
     */
    static async getStorageQuota(req, res) {
        try {
            const activeDb = req.propertyDb;
            const outletId = Number(req.outlet_id || req.user?.outlet_id || req.query?.outlet_id || 1);
            const outletCode = String(req.outlet_code ||
                req.user?.outlet_code ||
                req.outlet?.outlet_code ||
                req.outlet?.code ||
                req.query?.outlet_code ||
                `OUT_${outletId}`);
            const quotaStatus = await storageQuota_service_1.default.calculateTenantStorage(activeDb, outletId, outletCode);
            return res.json({
                success: true,
                data: quotaStatus,
            });
        }
        catch (err) {
            console.error('getStorageQuota error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Failed to retrieve storage quota.' });
        }
    }
    /**
     * 18. 1-Click Monthly Storage Expansion
     * POST /api/backup/storage-quota/upgrade
     */
    static async upgradeStorageQuota(req, res) {
        try {
            const activeDb = req.propertyDb;
            const outletCode = String(req.body?.outletCode ||
                req.outlet_code ||
                req.user?.outlet_code ||
                req.outlet?.outlet_code ||
                req.outlet?.code ||
                '');
            const addonPlanCode = String(req.body?.addonPlanCode || req.body?.planCode || 'ADDON_25GB').toUpperCase();
            if (!outletCode) {
                return res.status(400).json({ success: false, message: 'Outlet code required for storage upgrade.' });
            }
            const result = await storageQuota_service_1.default.upgradeStorageAddon(activeDb, outletCode, addonPlanCode);
            return res.json({
                success: true,
                message: result.message,
                data: result,
            });
        }
        catch (err) {
            console.error('upgradeStorageQuota error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Storage upgrade failed.' });
        }
    }
    /**
     * 19. Admin Console: Enterprise Storage Overview & Paid Subscriptions
     * GET /api/backup/admin/storage-overview
     */
    static async getAdminStorageOverview(req, res) {
        try {
            const activeDb = req.propertyDb;
            const overview = await storageQuota_service_1.default.getEnterpriseStorageOverview(activeDb);
            return res.json({
                success: true,
                data: overview,
            });
        }
        catch (err) {
            console.error('getAdminStorageOverview error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Failed to load enterprise storage overview.' });
        }
    }
    /**
     * 20. Admin Console: Manually Increase / Grant Storage Quota to Any Client
     * POST /api/backup/admin/modify-storage
     */
    static async adminModifyStorage(req, res) {
        try {
            const activeDb = req.propertyDb;
            const outletCode = String(req.body?.outletCode || req.body?.outlet_code || '').trim();
            const action = String(req.body?.action || 'ADD_GB').toUpperCase();
            const additionalGb = Number(req.body?.additionalGb || req.body?.additional_gb || 0);
            const totalGb = Number(req.body?.totalGb || req.body?.total_gb || 0);
            const notes = req.body?.notes ? String(req.body.notes) : undefined;
            if (!outletCode) {
                return res.status(400).json({ success: false, message: 'Target outlet_code required.' });
            }
            const result = await storageQuota_service_1.default.adminModifyStorage(activeDb, {
                outletCode,
                action,
                additionalGb,
                totalGb,
                notes,
            });
            return res.json({
                success: true,
                message: result.message,
                data: result.data,
            });
        }
        catch (err) {
            console.error('adminModifyStorage error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Failed to modify outlet storage quota.' });
        }
    }
    /**
     * 21. Automatic Storage Expansion on Payment Success
     * POST /api/backup/storage-quota/payment-success
     */
    static async processStoragePaymentSuccess(req, res) {
        try {
            const activeDb = req.propertyDb;
            const outletCode = String(req.body?.outletCode ||
                req.body?.outlet_code ||
                req.outlet_code ||
                req.user?.outlet_code ||
                '').trim();
            const planCode = String(req.body?.planCode || req.body?.plan_code || 'ADDON_25GB').toUpperCase();
            const amount = Number(req.body?.amount || 0);
            const transactionId = req.body?.transactionId || req.body?.transaction_id || `TXN_${Date.now()}`;
            if (!outletCode) {
                return res.status(400).json({ success: false, message: 'Outlet code required for storage payment processing.' });
            }
            const result = await storageQuota_service_1.default.processPaymentSuccess(activeDb, {
                outletCode,
                planCode,
                amount,
                transactionId,
            });
            return res.json({
                success: true,
                message: result.message,
                data: result.quota,
            });
        }
        catch (err) {
            console.error('processStoragePaymentSuccess error:', err);
            return res.status(500).json({ success: false, message: err.message || 'Payment storage expansion failed.' });
        }
    }
}
exports.BackupManagementController = BackupManagementController;
exports.default = BackupManagementController;
module.exports = BackupManagementController;
