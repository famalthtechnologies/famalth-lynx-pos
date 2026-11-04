"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const communityController = __importStar(require("../controllers/community.controller"));
const router = (0, express_1.Router)();
router.get('/conversations', communityController.getConversations);
router.post('/conversations', communityController.createConversation);
router.get('/conversations/discover', communityController.discoverConversations);
router.get('/merchants', communityController.getMerchants);
router.get('/messages', communityController.getMessages);
router.post('/messages', communityController.sendMessage);
router.post('/messages/edit', communityController.editMessage);
router.put('/messages/:id', communityController.editMessage);
router.post('/messages/delete-for-everyone', communityController.deleteForEveryone);
router.post('/messages/delete-for-me', communityController.deleteForMe);
router.post('/merchants/block', communityController.blockUser);
router.post('/merchants/unblock', communityController.unblockUser);
router.get('/merchants/blocked', communityController.getBlockedUsers);
router.post('/channels/exit', communityController.exitChannel);
router.post('/channels/join', communityController.joinChannel);
router.post('/conversations/clear', communityController.clearConversation);
module.exports = router;
exports.default = router;
