"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const ctrl = require('../controllers/whatsapp/whatsappWebhook.controller');
// Public endpoints (no authentication middleware)
router.get('/', ctrl.verifyWebhook);
router.post('/', ctrl.receiveWebhook);
module.exports = router;
exports.default = router;
