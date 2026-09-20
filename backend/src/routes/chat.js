const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');

router.get('/rooms', verifyFirebaseToken, async (req, res) => {
  const rooms = [
    { roomId: 'r1', otherUserName: 'Rajesh Gupta', lastMessage: 'What is your asking price?', unreadCount: 2, lastMessageTime: new Date().toISOString() },
  ];
  res.json({ data: rooms });
});

router.post('/rooms', verifyFirebaseToken, async (req, res) => {
  const { buyerUID } = req.body;
  const roomId = [req.user.uid, buyerUID].sort().join('_');
  res.status(201).json({ roomId, createdAt: new Date().toISOString() });
});

module.exports = router;
