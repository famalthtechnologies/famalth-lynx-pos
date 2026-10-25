import express from 'express';
const router = express.Router();
const auth = require('../middlewares/auth.middleware');
const gatewaysCtrl = require('../controllers/payments/paymentGateways.controller');

router.use(auth);

router.get('/config', gatewaysCtrl.getGatewaysConfig);
router.post('/config', gatewaysCtrl.saveGatewaysConfig);
router.get('/usb-devices', gatewaysCtrl.getUsbConnectedDevices);
router.post('/usb-mobile/push-qr', gatewaysCtrl.pushQrToUsbMobile);

module.exports = router;
export default router;
