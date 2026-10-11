const axios = require('axios');
const env = require('../config/env');

async function callML(endpoint, data) {
  try {
    if (!env.ML_SERVICE_SECRET && env.NODE_ENV !== 'development') {
      throw new Error('ML_SERVICE_SECRET is not configured on the backend');
    }
    const res = await axios.post(`${env.ML_SERVICE_URL}${endpoint}`, data, {
      headers: env.ML_SERVICE_SECRET ? { 'X-Secret': env.ML_SERVICE_SECRET } : {},
      timeout: 30000,
    });
    return res.data;
  } catch (err) {
    // Fallback to mock data in development
    if (env.NODE_ENV === 'development') {
      return getMockResponse(endpoint, data);
    }
    throw err;
  }
}

function getMockResponse(endpoint, data) {
  if (endpoint === '/predict') {
    const basePrice = { 'Tomato': 1500, 'Onion': 950, 'Wheat': 2250 }[data.commodity] || 1000;
    const days = data.days || 7;
    return {
      commodity: data.commodity,
      state: data.state,
      points: Array.from({ length: days }, (_, i) => ({
        date: new Date(Date.now() + (i + 1) * 86400000).toISOString().split('T')[0],
        price: basePrice * (1 + i * 0.005 + (Math.random() - 0.5) * 0.08),
        lowerBound: basePrice * 0.88,
        upperBound: basePrice * 1.12,
      })),
      confidence: 0.82,
      unit: 'INR/quintal',
      generatedAt: new Date().toISOString(),
    };
  }
  if (endpoint === '/crop-reco') {
    return {
      recommendations: [
        { crop: 'Tomato', matchScore: 0.91, reason: 'High demand, suitable climate' },
        { crop: 'Wheat', matchScore: 0.85, reason: 'Good soil match' },
        { crop: 'Onion', matchScore: 0.79, reason: 'Strong market prices' },
      ],
    };
  }
  if (endpoint === '/demand') {
    return { demandLevel: 'HIGH', demandIndex: 0.78, trend: 'RISING', peakExpectedDays: 5 };
  }
  return {};
}

module.exports = {
  getPricePrediction: (commodity, state, days) => callML('/predict', { commodity, state, days }),
  getCropRecommendation: (params) => callML('/crop-reco', params),
  getDemandForecast: (commodity, state) => callML('/demand', { commodity, state }),
};
