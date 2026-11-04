"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const intelligenceController = require('../controllers/intelligence.controller');
// GET /api/v1/intelligence/recommendations?itemIds=1,2&itemCodes=ITEM1,ITEM2
router.get('/recommendations', intelligenceController.getCartRecommendations);
// GET /api/v1/intelligence/customer-insights/:id?phone=9876543210
router.get('/customer-insights/:id', intelligenceController.getCustomerInsights);
module.exports = router;
exports.default = router;
