"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/report/nightAudit.controller');
router.use(auth);
router.get('/status', ctrl.getStatus);
router.post('/validate', ctrl.validate);
router.post('/execute', license('ADMIN'), ctrl.execute);
router.get('/history', ctrl.getHistory);
router.post('/clear-kots', ctrl.clearKots);
module.exports = router;
exports.default = router;
