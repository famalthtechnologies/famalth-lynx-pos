import express from 'express';
import BackupManagementController from '../controllers/backup/backupManagement.controller';

const rawAuth = require('../middlewares/auth.middleware');
const authMiddleware = rawAuth.authMiddleware || rawAuth.default || rawAuth;

const rawOutlet = require('../middlewares/outlet.middleware');
const outletMiddleware = rawOutlet.outletMiddleware || rawOutlet.default || rawOutlet;

const router = express.Router();

// 1. Enterprise storage statistics & backup status
router.get('/storage-stats', authMiddleware, outletMiddleware, BackupManagementController.getStorageStats);

// 1b. Enterprise console complete & outlet-wise storage analytics
router.get('/enterprise-storage', authMiddleware, BackupManagementController.getEnterpriseStorageStats);

// 2. Take tenant-isolated backup (Downloadable .posbak)
router.post('/tenant-backup', authMiddleware, outletMiddleware, BackupManagementController.createTenantBackup);

// 3. Direct download backup file
router.get('/download/:filename', authMiddleware, outletMiddleware, BackupManagementController.downloadBackup);

// 4. Restore / migrate tenant backup
router.post('/restore-tenant-backup', authMiddleware, outletMiddleware, BackupManagementController.restoreTenantBackup);

// 5. Delete backup
router.delete('/:filename', authMiddleware, outletMiddleware, BackupManagementController.deleteBackup);

// 6. Enterprise full system backup (Super Admin)
router.post('/system-backup', authMiddleware, BackupManagementController.createSystemBackup);

// 7. Enterprise restore full system backup (Super Admin)
router.post('/restore-system-backup', authMiddleware, BackupManagementController.restoreSystemBackup);

// 8. Granular .fambak archive backup (All Outlets or Scoped Outlet)
router.post('/create-fambak', authMiddleware, outletMiddleware, BackupManagementController.createFambakBackup);

// 9. Pre-inspect backup manifest
router.post('/inspect-backup', authMiddleware, outletMiddleware, BackupManagementController.inspectBackupManifest);

// 10. Restore .fambak archive (Selective Outlet Restore or Full Enterprise)
router.post('/restore-fambak', authMiddleware, outletMiddleware, BackupManagementController.restoreFambakBackup);

// 11. List cloud snapshots history
router.get('/cloud-backups', authMiddleware, outletMiddleware, BackupManagementController.listCloudBackups);

// 12. 1-Click restore cloud snapshot
router.post('/restore-cloud-backup', authMiddleware, outletMiddleware, BackupManagementController.restoreCloudBackup);

// 13. Off-server secure download link via email
router.post('/email-backup-link', authMiddleware, outletMiddleware, BackupManagementController.emailBackupLink);

// 14. Download backup archive using signed email token (Public / Token-authenticated)
router.get('/email-download', BackupManagementController.downloadViaEmailToken);

// 15. Provider Control Plane: Preview Cloud Data Retention Pruning
router.post('/provider/retention-preview', authMiddleware, BackupManagementController.previewProviderRetention);

// 16. Provider Control Plane: Execute Cloud Data Retention Pruning
router.post('/provider/retention-purge', authMiddleware, BackupManagementController.executeProviderRetention);

export default router;
module.exports = router;
