const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');

router.get('/weather', verifyFirebaseToken, async (req, res) => {
  const { lat, lng } = req.query;
  // In production: call OpenWeather API
  res.json({ temperature: 28, humidity: 65, rainfall: 850, annualRainfall: 850, description: 'Partly Cloudy', lat, lng });
});

router.get('/list', verifyFirebaseToken, async (req, res) => {
  const crops = ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Chillies', 'Soybean', 'Maize', 'Sugarcane'];
  res.json({ data: crops });
});

module.exports = router;
