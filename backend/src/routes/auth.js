const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');

// POST /api/auth/register - Save farmer profile
router.post('/register', verifyFirebaseToken, async (req, res) => {
  try {
    const { name, state, district, crops, language, location } = req.body;
    const uid = req.user.uid;
    // In production: save to Firestore users/{uid}
    const profile = { uid, name, state, district, crops, language, location, createdAt: new Date().toISOString() };
    res.status(201).json({ profile, message: 'Profile saved successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/profile
router.get('/profile', verifyFirebaseToken, async (req, res) => {
  try {
    res.json({ uid: req.user.uid, name: 'Demo Farmer', state: 'Karnataka', crops: ['Tomato', 'Onion'] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
