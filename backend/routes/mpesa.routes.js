"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const auth = require('../middlewares/auth.middleware');
const mpesaCtrl = require('../controllers/payments/mpesa.controller');
// Public webhook callback
router.post('/callback', mpesaCtrl.handleCallback);
// Protected routes
router.use(auth);
router.get('/config', mpesaCtrl.getConfig);
router.post('/config', mpesaCtrl.saveConfig);
router.post('/stk-push', mpesaCtrl.initiateStkPush);
router.post('/stk-query', mpesaCtrl.queryStkStatus);
module.exports = router;
exports.default = router;
