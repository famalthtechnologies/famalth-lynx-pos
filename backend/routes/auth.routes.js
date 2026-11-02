const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const ctrl = require('../controllers/auth/login.controller');

const { loginLimiter, terminalIpLimiter } = require('../middlewares/rateLimit.middleware');

router.post('/login', terminalIpLimiter, loginLimiter, ctrl.login);
router.get('/quick-users', ctrl.getQuickUsers);
router.post('/pin-login', terminalIpLimiter, loginLimiter, ctrl.pinLogin);
router.post('/qr-login', terminalIpLimiter, loginLimiter, ctrl.loginWithQrToken);
router.post('/switch-outlet', auth, ctrl.switchOutlet);
router.post('/supplier/request-otp', terminalIpLimiter, loginLimiter, ctrl.requestSupplierOtp);
router.post('/supplier/verify-otp', ctrl.verifySupplierOtp);

module.exports = router;
