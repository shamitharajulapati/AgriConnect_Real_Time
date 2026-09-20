const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');
const mlService = require('../services/ml.service');

// POST /api/ml/predict - Price prediction
router.post('/predict', verifyFirebaseToken, async (req, res) => {
  try {
    const { commodity, state, days = 7 } = req.body;
    if (!commodity || !state) return res.status(400).json({ error: 'commodity and state required' });
    const result = await mlService.getPricePrediction(commodity, state, days);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/ml/crop-reco - Crop recommendation
router.post('/crop-reco', verifyFirebaseToken, async (req, res) => {
  try {
    const { latitude, longitude, state, soilType, temperature, humidity, rainfall } = req.body;
    const result = await mlService.getCropRecommendation({ latitude, longitude, state, soilType, temperature, humidity, rainfall });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/ml/demand - Demand forecast
router.get('/demand/:commodity/:state', verifyFirebaseToken, async (req, res) => {
  try {
    const { commodity, state } = req.params;
    const result = await mlService.getDemandForecast(commodity, state);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
