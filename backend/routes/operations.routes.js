"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const operationsController = require('../controllers/operations.controller');
// GET /api/v1/operations/health-snapshot
router.get('/health-snapshot', operationsController.getHealthSnapshot);
// GET /api/v1/operations/reorder-alerts
router.get('/reorder-alerts', operationsController.getReorderAlerts);
// GET /api/v1/operations/expiry-alerts?days=60
router.get('/expiry-alerts', operationsController.getExpiryAlerts);
module.exports = router;
exports.default = router;
