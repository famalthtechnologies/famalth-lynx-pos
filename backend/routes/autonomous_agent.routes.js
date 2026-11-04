"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const agentController = require('../controllers/autonomous_agent.controller');
// GET /api/v1/agent/proposals
router.get('/proposals', agentController.getProposals);
// POST /api/v1/agent/proposals/:id/approve
router.post('/proposals/:id/approve', agentController.approveProposal);
// POST /api/v1/agent/proposals/:id/reject
router.post('/proposals/:id/reject', agentController.rejectProposal);
// GET /api/v1/agent/audit-logs
router.get('/audit-logs', agentController.getAuditLogs);
module.exports = router;
exports.default = router;
