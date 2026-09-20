const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../middleware/auth');
const { syncMarketPrices, seedInitialPrices } = require('../services/market_price.service');
const supabase = require('../config/supabase');

// GET /api/market/prices — with filters
router.get('/prices', verifyFirebaseToken, async (req, res) => {
  try {
    const { commodity, state, limit = 50 } = req.query;
    let query = supabase
      .from('market_prices')
      .select('*')
      .order('arrival_date', { ascending: false })
      .limit(parseInt(limit));

    if (state && state !== 'All States') query = query.eq('state', state);
    if (commodity && commodity !== 'All')  query = query.eq('commodity', commodity);

    const { data, error } = await query;
    if (error) throw error;

    res.json({ data, count: data.length, source: data[0]?.source || 'unknown' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/market/prices/:state
router.get('/prices/:state', verifyFirebaseToken, async (req, res) => {
  try {
    const { state } = req.params;
    const { commodity, limit = 50 } = req.query;

    let query = supabase
      .from('market_prices')
      .select('*')
      .order('arrival_date', { ascending: false })
      .limit(parseInt(limit));

    if (state !== 'all') query = query.eq('state', state);
    if (commodity) query = query.eq('commodity', commodity);

    const { data, error } = await query;
    if (error) throw error;

    res.json({ data, count: data.length, state });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/market/sync — manual trigger
router.post('/sync', verifyFirebaseToken, async (req, res) => {
  try {
    const { state, commodity } = req.body;
    const count = await syncMarketPrices(state, commodity);
    res.json({ synced: count, state, commodity, message: `Synced ${count} records from available sources` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/market/seed — force re-seed
router.post('/seed', verifyFirebaseToken, async (req, res) => {
  try {
    const { getSeedPrices } = require('../services/market_price.service');
    const records = getSeedPrices();
    const { error } = await supabase.from('market_prices').upsert(records, { onConflict: 'id' });
    if (error) throw error;
    res.json({ seeded: records.length, message: 'Seed data inserted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/market/commodities — list available commodities
router.get('/commodities', verifyFirebaseToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('market_prices')
      .select('commodity')
      .order('commodity');
    if (error) throw error;
    const unique = [...new Set(data.map(r => r.commodity))];
    res.json({ data: unique });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
