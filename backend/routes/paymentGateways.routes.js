"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const auth = require('../middlewares/auth.middleware');
const gatewaysCtrl = require('../controllers/payments/paymentGateways.controller');
router.use(auth);
router.get('/config', gatewaysCtrl.getGatewaysConfig);
router.post('/config', gatewaysCtrl.saveGatewaysConfig);
router.get('/usb-devices', gatewaysCtrl.getUsbConnectedDevices);
router.post('/usb-mobile/push-qr', gatewaysCtrl.pushQrToUsbMobile);
module.exports = router;
exports.default = router;
