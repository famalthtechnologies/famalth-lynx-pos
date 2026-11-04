"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const auth = require('../middlewares/auth.middleware');
const aiAssistCtrl = require('../controllers/ai_assist.controller');
router.use(auth);
// LYNX ASSIST AI Chat & Voice Assistant Endpoints
router.post('/chat', aiAssistCtrl.chatWithLynxAssist);
router.post('/voice-command', aiAssistCtrl.handleVoiceCommand);
module.exports = router;
exports.default = router;
