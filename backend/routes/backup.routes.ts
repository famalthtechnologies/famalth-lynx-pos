import express from 'express';
import BackupManagementController from '../controllers/backup/backupManagement.controller';

const rawAuth = require('../middlewares/auth.middleware');
const authMiddleware = rawAuth.authMiddleware || rawAuth.default || rawAuth;

const rawOutlet = require('../middlewares/outlet.middleware');
const outletMiddleware = rawOutlet.outletMiddleware || rawOutlet.default || rawOutlet;

const rawJwt = require('../utils/jwt.util');
const jwtUtil = rawJwt.default || rawJwt;

/**
 * Flexible download authentication middleware:
 * - Checks Bearer Authorization header
 * - Checks ?token= query parameter (for direct browser downloads)
 * - Allows local loopback (127.0.0.1, ::1, localhost) on local POS terminals
 */
const downloadAuthMiddleware = async (req: express.Request, res: express.Response, next: express.NextFunction): Promise<any> => {
  try {
    const token = req.headers.authorization?.split(' ')[1] || (req.query?.token as string);
    if (token) {
      try {
        const data: any = jwtUtil.verify(token);
        req.user = { ...data, id: data.user_id || data.id };
        (req as any).outlet_id = data.outlet_id;
        (req as any).outlet_code = data.outlet_code;
        return next();
      } catch (err: any) {
        // Token was provided but failed verification; continue to loopback check
      }
    }

    const ip = req.ip || req.socket?.remoteAddress || '';
    const isLoopback =
      ip.includes('127.0.0.1') ||
      ip === '::1' ||
      ip.includes('localhost') ||
      req.hostname === 'localhost' ||
      req.hostname === '127.0.0.1';

    if (isLoopback) {
      req.user = { role: 'SUPER_ADMIN', permissions: ['*'] };
      return next();
    }

    return res.status(401).json({
      success: false,
      message: 'Authentication token required to download backup. Please login or pass ?token= parameter.'
    });
  } catch (err: any) {
    return res.status(401).json({ success: false, message: 'Authentication failed' });
  }
};

const router = express.Router();

// 1. Enterprise storage statistics & backup status
router.get('/storage-stats', authMiddleware, outletMiddleware, BackupManagementController.getStorageStats);

// 1b. Enterprise console complete & outlet-wise storage analytics
router.get('/enterprise-storage', authMiddleware, BackupManagementController.getEnterpriseStorageStats);

// 2. Take tenant-isolated backup (Downloadable .posbak)
router.post('/tenant-backup', authMiddleware, outletMiddleware, BackupManagementController.createTenantBackup);

// 3. Direct download backup file
router.get('/download/:filename', downloadAuthMiddleware, BackupManagementController.downloadBackup);

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

// 17. Metered cloud storage quota & breakdown
router.get('/storage-quota', authMiddleware, outletMiddleware, BackupManagementController.getStorageQuota);

// 18. 1-Click monthly storage add-on upgrade
router.post('/storage-quota/upgrade', authMiddleware, outletMiddleware, BackupManagementController.upgradeStorageQuota);


// 19. Admin Console: Enterprise Storage Overview
router.get('/admin/storage-overview', authMiddleware, BackupManagementController.getAdminStorageOverview);

// 20. Admin Console: Manually grant/modify storage for client outlet
router.post('/admin/modify-storage', authMiddleware, BackupManagementController.adminModifyStorage);

// 21. Automatic recurring storage addition on payment success
router.post('/storage-quota/payment-success', authMiddleware, BackupManagementController.processStoragePaymentSuccess);

export default router;
module.exports = router;
