"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const workflowController = require('../controllers/workflow.controller');
// GET /api/v1/workflows/rules
router.get('/rules', workflowController.getWorkflowRules);
// POST /api/v1/workflows/rules/:id/toggle
router.post('/rules/:id/toggle', workflowController.toggleWorkflowRule);
// POST /api/v1/workflows/trigger
router.post('/trigger', workflowController.triggerWorkflow);
module.exports = router;
exports.default = router;
