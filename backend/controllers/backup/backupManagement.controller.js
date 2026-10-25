"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BackupManagementController = void 0;
const tenantBackup_service_1 = __importDefault(require("../../services/tenantBackup.service"));
const fs_1 = __importDefault(require("fs"));
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
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
}
exports.BackupManagementController = BackupManagementController;
exports.default = BackupManagementController;
