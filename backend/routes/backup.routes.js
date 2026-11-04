"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const backupManagement_controller_1 = __importDefault(require("../controllers/backup/backupManagement.controller"));
const rawAuth = require('../middlewares/auth.middleware');
const authMiddleware = rawAuth.authMiddleware || rawAuth.default || rawAuth;
const rawOutlet = require('../middlewares/outlet.middleware');
const outletMiddleware = rawOutlet.outletMiddleware || rawOutlet.default || rawOutlet;
const router = express_1.default.Router();
// 1. Enterprise storage statistics & backup status
router.get('/storage-stats', authMiddleware, outletMiddleware, backupManagement_controller_1.default.getStorageStats);
// 1b. Enterprise console complete & outlet-wise storage analytics
router.get('/enterprise-storage', authMiddleware, backupManagement_controller_1.default.getEnterpriseStorageStats);
// 2. Take tenant-isolated backup (Downloadable .posbak)
router.post('/tenant-backup', authMiddleware, outletMiddleware, backupManagement_controller_1.default.createTenantBackup);
// 3. Direct download backup file
router.get('/download/:filename', authMiddleware, outletMiddleware, backupManagement_controller_1.default.downloadBackup);
// 4. Restore / migrate tenant backup
router.post('/restore-tenant-backup', authMiddleware, outletMiddleware, backupManagement_controller_1.default.restoreTenantBackup);
// 5. Delete backup
router.delete('/:filename', authMiddleware, outletMiddleware, backupManagement_controller_1.default.deleteBackup);
// 6. Enterprise full system backup (Super Admin)
router.post('/system-backup', authMiddleware, backupManagement_controller_1.default.createSystemBackup);
// 7. Enterprise restore full system backup (Super Admin)
router.post('/restore-system-backup', authMiddleware, backupManagement_controller_1.default.restoreSystemBackup);
// 8. Granular .fambak archive backup (All Outlets or Scoped Outlet)
router.post('/create-fambak', authMiddleware, outletMiddleware, backupManagement_controller_1.default.createFambakBackup);
// 9. Pre-inspect backup manifest
router.post('/inspect-backup', authMiddleware, outletMiddleware, backupManagement_controller_1.default.inspectBackupManifest);
// 10. Restore .fambak archive (Selective Outlet Restore or Full Enterprise)
router.post('/restore-fambak', authMiddleware, outletMiddleware, backupManagement_controller_1.default.restoreFambakBackup);
// 11. List cloud snapshots history
router.get('/cloud-backups', authMiddleware, outletMiddleware, backupManagement_controller_1.default.listCloudBackups);
// 12. 1-Click restore cloud snapshot
router.post('/restore-cloud-backup', authMiddleware, outletMiddleware, backupManagement_controller_1.default.restoreCloudBackup);
// 13. Off-server secure download link via email
router.post('/email-backup-link', authMiddleware, outletMiddleware, backupManagement_controller_1.default.emailBackupLink);
// 14. Download backup archive using signed email token (Public / Token-authenticated)
router.get('/email-download', backupManagement_controller_1.default.downloadViaEmailToken);
// 15. Provider Control Plane: Preview Cloud Data Retention Pruning
router.post('/provider/retention-preview', authMiddleware, backupManagement_controller_1.default.previewProviderRetention);
// 16. Provider Control Plane: Execute Cloud Data Retention Pruning
router.post('/provider/retention-purge', authMiddleware, backupManagement_controller_1.default.executeProviderRetention);
exports.default = router;
module.exports = router;
