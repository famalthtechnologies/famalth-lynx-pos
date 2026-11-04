"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const notifyCtrl = require('../controllers/inventory/systemnotification.controller');
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
router.use(auth, license('INVENTORY'));
router.get('/', notifyCtrl.getNotifications);
router.post('/', notifyCtrl.createNotification);
router.put('/mark-all-read', notifyCtrl.markAllNotificationsRead);
router.put('/:id/read', notifyCtrl.markNotificationRead);
router.delete('/:id', notifyCtrl.deleteNotification);
module.exports = router;
exports.default = router;
