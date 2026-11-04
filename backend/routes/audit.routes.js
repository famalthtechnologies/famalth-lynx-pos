"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/report/audit.controller');
router.use(auth, license('ADMIN'));
router.get('/', ctrl.auditReport);
module.exports = router;
exports.default = router;
