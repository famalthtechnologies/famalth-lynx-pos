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
exports.default = router;
module.exports = router;
