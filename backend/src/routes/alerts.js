const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');

router.get('/', verifyFirebaseToken, async (req, res) => {
  const alerts = [
    { id: 'a1', type: 'PRICE_SPIKE', commodity: 'Tomato', message: 'Tomato prices spiked 18%', isRead: false, createdAt: new Date().toISOString() },
    { id: 'a2', type: 'PRICE_TARGET', commodity: 'Onion', message: 'Onion reached target ₹900/qtl', isRead: false, createdAt: new Date().toISOString() },
  ];
  res.json({ data: alerts.filter(a => !req.query.unreadOnly || !a.isRead) });
});

router.post('/', verifyFirebaseToken, async (req, res) => {
  const { type, commodity, targetPrice } = req.body;
  const alert = { id: `a_${Date.now()}`, userId: req.user.uid, type, commodity, targetPrice, isActive: true, createdAt: new Date().toISOString() };
  res.status(201).json({ alert, message: 'Alert created' });
});

router.delete('/:id', verifyFirebaseToken, async (req, res) => {
  res.json({ message: `Alert ${req.params.id} deleted` });
});

module.exports = router;
