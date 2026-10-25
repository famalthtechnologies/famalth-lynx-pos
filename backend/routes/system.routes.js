"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const maintenance_controller_1 = __importDefault(require("../controllers/system/maintenance.controller"));
const router = (0, express_1.Router)();
// Public endpoint for clients to query maintenance state
router.get('/maintenance-status', maintenance_controller_1.default.getStatus);
// Admin endpoint to toggle and update maintenance window
router.post('/maintenance', maintenance_controller_1.default.setMaintenance);
exports.default = router;
module.exports = router;
