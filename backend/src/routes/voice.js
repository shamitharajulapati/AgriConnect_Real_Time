const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');

const PRICE_RESPONSES = {
  'hi': (commodity, price) => `आज ${commodity} का मोडल भाव ₹${price}/क्विंटल है।`,
  'en': (commodity, price) => `Today's modal price for ${commodity} is ₹${price}/quintal.`,
  'te': (commodity, price) => `ఈరోజు ${commodity} ధర ₹${price}/క్వింటాల్.`,
  'ta': (commodity, price) => `இன்று ${commodity} விலை ₹${price}/குவிண்டால்.`,
  'kn': (commodity, price) => `ಇಂದು ${commodity} ಬೆಲೆ ₹${price}/ಕ್ವಿಂಟಾಲ್.`,
};

function extractIntent(query, language) {
  const q = query.toLowerCase();
  if (q.includes('भाव') || q.includes('price') || q.includes('ధర') || q.includes('விலை') || q.includes('ಬೆಲೆ') || q.includes('दाम') || q.includes('rate')) {
    const crops = { 'tomato': 1500, 'टमाटर': 1500, 'onion': 950, 'प्याज': 950, 'wheat': 2250, 'गेहूं': 2250, 'potato': 750, 'आलू': 750 };
    for (const [key, price] of Object.entries(crops)) {
      if (q.includes(key)) {
        return { action: 'GET_PRICE', commodity: key, price };
      }
    }
    return { action: 'GET_PRICE', commodity: 'tomato', price: 1500 };
  }
  if (q.includes('फसल') || q.includes('crop') || q.includes('पीक') || q.includes('పంట') || q.includes('பயிர்')) {
    return { action: 'CROP_RECOMMENDATION' };
  }
  return { action: 'MARKET_OVERVIEW' };
}

// POST /api/voice/query
router.post('/query', verifyFirebaseToken, async (req, res) => {
  try {
    const { query, language = 'hi' } = req.body;
    if (!query) return res.status(400).json({ error: 'query required' });

    const intent = extractIntent(query, language);
    let answer;

    if (intent.action === 'GET_PRICE') {
      const fn = PRICE_RESPONSES[language] || PRICE_RESPONSES['en'];
      answer = fn(intent.commodity, intent.price);
    } else if (intent.action === 'CROP_RECOMMENDATION') {
      answer = language === 'hi'
        ? 'आपकी जमीन के लिए टमाटर, गेहूं और चने की खेती सबसे अच्छी रहेगी।'
        : 'Tomato, Wheat, and Chickpea are best for your soil and climate.';
    } else {
      answer = language === 'hi'
        ? 'आज मंडी में टमाटर ₹1500, प्याज ₹950, और गेहूं ₹2250/क्विंटल है।'
        : 'Today: Tomato ₹1500, Onion ₹950, Wheat ₹2250/quintal.';
    }

    res.json({ answer, intent, language });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
