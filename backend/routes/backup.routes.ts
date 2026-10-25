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

export default router;
module.exports = router;
