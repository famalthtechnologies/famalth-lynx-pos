const express = require('express');
const router = express.Router();
const communityController = require('../controllers/community.controller');

// Conversation list / create / discover
router.get('/conversations', communityController.getConversations);
router.post('/conversations', communityController.createConversation);
router.get('/conversations/discover', communityController.discoverConversations);
router.get('/merchants', communityController.getMerchants);

// Message retrieval & sending
router.get('/messages', communityController.getMessages);
router.post('/messages', communityController.sendMessage);
router.post('/messages/edit', communityController.editMessage);
router.put('/messages/:id', communityController.editMessage);

// Message deletions
router.post('/messages/delete-for-everyone', communityController.deleteForEveryone);
router.post('/messages/delete-for-me', communityController.deleteForMe);

// Block/Unblock & Exit
router.post('/merchants/block', communityController.blockUser);
router.post('/merchants/unblock', communityController.unblockUser);
router.get('/merchants/blocked', communityController.getBlockedUsers);
router.post('/channels/exit', communityController.exitChannel);
router.post('/channels/join', communityController.joinChannel);
router.post('/conversations/clear', communityController.clearConversation);

module.exports = router;

