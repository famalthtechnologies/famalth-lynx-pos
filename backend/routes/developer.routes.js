"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const developerController = require('../controllers/developer.controller');
const mcpController = require('../controllers/mcp.controller');
// GET /api/v1/developer/ecosystem/info
router.get('/ecosystem/info', developerController.getEcosystemInfo);
// Webhook routes
router.get('/webhooks', developerController.getWebhooks);
router.post('/webhooks', developerController.registerWebhook);
router.delete('/webhooks/:id', developerController.deleteWebhook);
router.post('/webhooks/:id/test', developerController.testWebhook);
// API Keys routes (both /api-keys and /apikeys supported to prevent 404s)
router.get('/api-keys', developerController.getApiKeys);
router.post('/api-keys', developerController.generateApiKey);
router.delete('/api-keys/:id', developerController.deleteApiKey);
router.get('/apikeys', developerController.getApiKeys);
router.post('/apikeys', developerController.generateApiKey);
router.delete('/apikeys/:id', developerController.deleteApiKey);
// OAuth 2.0 RFC 6749 Client Credentials Token Endpoint
router.post('/oauth/token', developerController.issueOAuthToken);
// =========================================================================
// Model Context Protocol (MCP) & AI Gateway Routes (ChatGPT, Gemini, Claude)
// =========================================================================
// MCP Configuration, Tools Metadata & Diagnostics
router.get('/mcp/config', mcpController.getMcpConfig);
router.get('/mcp/tools', mcpController.getMcpTools);
// ChatGPT OpenAPI 3.0 Spec & Gemini Function Calling Spec
router.get('/mcp/chatgpt-openapi.json', mcpController.getChatGptSpec);
router.get('/mcp/gemini-tools.json', mcpController.getGeminiSpec);
// Standard MCP Protocol Transports
router.post('/mcp', mcpController.handleJsonRpc); // JSON-RPC 2.0 over HTTP
router.get('/mcp/sse', mcpController.handleSse); // Remote MCP Server-Sent Events stream
router.post('/mcp/messages', mcpController.handleMessages); // MCP SSE Messages endpoint
// Direct Tool Execution & ChatGPT Action Endpoints
router.post('/mcp/tools/execute', mcpController.executeToolDirect);
router.post('/mcp/tools/analyze-sales', mcpController.toolAnalyzeSales);
router.post('/mcp/tools/create-order-bill', mcpController.toolCreateOrderBill);
router.post('/mcp/tools/inventory-status', mcpController.toolInventoryStatus);
router.post('/mcp/tools/search-products', mcpController.toolSearchProducts);
module.exports = router;
exports.default = router;
