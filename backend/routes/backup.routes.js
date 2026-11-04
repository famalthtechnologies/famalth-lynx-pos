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
const rawJwt = require('../utils/jwt.util');
const jwtUtil = rawJwt.default || rawJwt;
/**
 * Flexible download authentication middleware:
 * - Checks Bearer Authorization header
 * - Checks ?token= query parameter (for direct browser downloads)
 * - Allows local loopback (127.0.0.1, ::1, localhost) on local POS terminals
 */
const downloadAuthMiddleware = async (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1] || req.query?.token;
        if (token) {
            try {
                const data = jwtUtil.verify(token);
                req.user = { ...data, id: data.user_id || data.id };
                req.outlet_id = data.outlet_id;
                req.outlet_code = data.outlet_code;
                return next();
            }
            catch (err) {
                // Token was provided but failed verification; continue to loopback check
            }
        }
        const ip = req.ip || req.socket?.remoteAddress || '';
        const isLoopback = ip.includes('127.0.0.1') ||
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
    }
    catch (err) {
        return res.status(401).json({ success: false, message: 'Authentication failed' });
    }
};
const router = express_1.default.Router();
// 1. Enterprise storage statistics & backup status
router.get('/storage-stats', authMiddleware, outletMiddleware, backupManagement_controller_1.default.getStorageStats);
// 1b. Enterprise console complete & outlet-wise storage analytics
router.get('/enterprise-storage', authMiddleware, backupManagement_controller_1.default.getEnterpriseStorageStats);
// 2. Take tenant-isolated backup (Downloadable .posbak)
router.post('/tenant-backup', authMiddleware, outletMiddleware, backupManagement_controller_1.default.createTenantBackup);
// 3. Direct download backup file
router.get('/download/:filename', downloadAuthMiddleware, backupManagement_controller_1.default.downloadBackup);
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
// 17. Metered cloud storage quota & breakdown
router.get('/storage-quota', authMiddleware, outletMiddleware, backupManagement_controller_1.default.getStorageQuota);
// 18. 1-Click monthly storage add-on upgrade
router.post('/storage-quota/upgrade', authMiddleware, outletMiddleware, backupManagement_controller_1.default.upgradeStorageQuota);
// 19. Admin Console: Enterprise Storage Overview
router.get('/admin/storage-overview', authMiddleware, backupManagement_controller_1.default.getAdminStorageOverview);
// 20. Admin Console: Manually grant/modify storage for client outlet
router.post('/admin/modify-storage', authMiddleware, backupManagement_controller_1.default.adminModifyStorage);
// 21. Automatic recurring storage addition on payment success
router.post('/storage-quota/payment-success', authMiddleware, backupManagement_controller_1.default.processStoragePaymentSuccess);
exports.default = router;
module.exports = router;
