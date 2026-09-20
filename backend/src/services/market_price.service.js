require('dotenv').config();
const axios = require('axios');
const supabase = require('../config/supabase');
const logger = require('../config/logger');

// ─────────────────────────────────────────────────────────────
// SOURCE 1: data.gov.in with PUBLIC demo key (no registration)
// ─────────────────────────────────────────────────────────────
const DEMO_KEY = '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';
const AGMARKNET_URL = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';

async function fetchFromDataGovIn(state, commodity) {
  try {
    const params = {
      'api-key': process.env.AGMARKNET_KEY || DEMO_KEY,
      format: 'json',
      limit: 500,
    };
    if (state) params['filters[state]'] = state;
    if (commodity) params['filters[commodity]'] = commodity;

    const res = await axios.get(AGMARKNET_URL, { params, timeout: 12000 });
    const records = res.data?.records ?? [];
    logger.info(`[DataGovIn] Fetched ${records.length} records for ${state}`);
    return records.map(normalizeRecord);
  } catch (err) {
    logger.warn(`[DataGovIn] Failed: ${err.message}`);
    return null; // trigger fallback
  }
}

// ─────────────────────────────────────────────────────────────
// SOURCE 2: eNAM API (National Agriculture Market — no key)
// ─────────────────────────────────────────────────────────────
const ENAM_URL = 'https://enam.gov.in/web/dashboard_annexure/trade_data';

async function fetchFromENAM(commodity) {
  try {
    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString().split('T')[0];

    const res = await axios.get(ENAM_URL, {
      params: {
        language: 'en',
        fromDate: weekAgo,
        toDate: today,
        commodity: commodity || '',
        limit: 200,
      },
      timeout: 12000,
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
    });

    const data = res.data?.data ?? res.data?.records ?? [];
    if (!data.length) return null;

    logger.info(`[eNAM] Fetched ${data.length} records`);
    return data.map(r => ({
      id: `enam_${r.stateName}_${r.apmc}_${r.commodity}_${r.date}`.replace(/[^a-zA-Z0-9_-]/g, '_'),
      commodity: r.commodity || r.commodityName,
      market: r.apmc || r.market,
      state: r.stateName || r.state,
      district: r.district || '',
      min_price: parseFloat(r.minPrice || r.min_price) || 0,
      max_price: parseFloat(r.maxPrice || r.max_price) || 0,
      modal_price: parseFloat(r.modalPrice || r.modal_price) || 0,
      unit: 'quintal',
      arrival_date: r.date || today,
      source: 'enam',
    })).filter(r => r.modal_price > 0);
  } catch (err) {
    logger.warn(`[eNAM] Failed: ${err.message}`);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// SOURCE 3: Agmarknet Website Scraper (no key needed)
// ─────────────────────────────────────────────────────────────
const AGMARKNET_SCRAPE_URL = 'https://agmarknet.gov.in/PriceTrend.aspx';

async function fetchFromScraper(commodity, state) {
  try {
    const res = await axios.get('https://agmarknet.gov.in/SearchCommoditywise.aspx', {
      params: {
        kwd: commodity || 'Tomato',
        ft: 'SO',
        Fy: '2024',
      },
      timeout: 15000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      },
    });

    // Parse price table from HTML
    const html = res.data;
    const records = parseAgmarknetHTML(html, commodity, state);
    logger.info(`[Scraper] Parsed ${records.length} records`);
    return records.length ? records : null;
  } catch (err) {
    logger.warn(`[Scraper] Failed: ${err.message}`);
    return null;
  }
}

function parseAgmarknetHTML(html, commodity, state) {
  const records = [];
  const today = new Date().toISOString().split('T')[0];
  // Match table rows: <td> values in price tables
  const rowRegex = /<tr[^>]*>[\s\S]*?<\/tr>/gi;
  const cellRegex = /<td[^>]*>([\s\S]*?)<\/td>/gi;
  const rows = html.match(rowRegex) || [];

  for (const row of rows) {
    const cells = [];
    let m;
    while ((m = cellRegex.exec(row)) !== null) {
      cells.push(m[1].replace(/<[^>]+>/g, '').trim());
    }
    if (cells.length >= 5) {
      const min = parseFloat(cells.find(c => /^\d+(\.\d+)?$/.test(c))) || 0;
      if (min > 0 && min < 100000) {
        records.push({
          id: `scrape_${state}_${commodity}_${Date.now()}`,
          commodity: commodity || 'Unknown',
          market: cells[1] || 'Unknown Market',
          state: state || cells[0] || 'Unknown',
          district: '',
          min_price: min,
          max_price: parseFloat(cells[3]) || min * 1.15,
          modal_price: parseFloat(cells[2]) || min * 1.08,
          unit: 'quintal',
          arrival_date: today,
          source: 'agmarknet_scrape',
        });
      }
    }
  }
  return records;
}

// ─────────────────────────────────────────────────────────────
// SOURCE 4: Seed real price data (guaranteed fallback)
// ─────────────────────────────────────────────────────────────
function getSeedPrices() {
  const today = new Date().toISOString().split('T')[0];
  // Real approximate prices as of 2024 (INR/quintal)
  return [
    { commodity: 'Tomato',    market: 'Azadpur',     state: 'Delhi',           min: 1000, modal: 1500, max: 2000 },
    { commodity: 'Tomato',    market: 'Kolar',        state: 'Karnataka',       min: 900,  modal: 1300, max: 1700 },
    { commodity: 'Tomato',    market: 'Nashik',       state: 'Maharashtra',     min: 800,  modal: 1200, max: 1600 },
    { commodity: 'Onion',     market: 'Lasalgaon',    state: 'Maharashtra',     min: 700,  modal: 950,  max: 1200 },
    { commodity: 'Onion',     market: 'Nashik',       state: 'Maharashtra',     min: 650,  modal: 880,  max: 1100 },
    { commodity: 'Onion',     market: 'Azadpur',      state: 'Delhi',           min: 800,  modal: 1050, max: 1300 },
    { commodity: 'Potato',    market: 'Agra',         state: 'Uttar Pradesh',   min: 500,  modal: 750,  max: 950  },
    { commodity: 'Potato',    market: 'Kolkata',      state: 'West Bengal',     min: 550,  modal: 780,  max: 980  },
    { commodity: 'Wheat',     market: 'Chandigarh',   state: 'Punjab',          min: 2100, modal: 2250, max: 2400 },
    { commodity: 'Wheat',     market: 'Ludhiana',     state: 'Punjab',          min: 2050, modal: 2200, max: 2350 },
    { commodity: 'Wheat',     market: 'Indore',       state: 'Madhya Pradesh',  min: 2000, modal: 2150, max: 2300 },
    { commodity: 'Rice',      market: 'Amritsar',     state: 'Punjab',          min: 2800, modal: 3000, max: 3200 },
    { commodity: 'Rice',      market: 'Patna',        state: 'Bihar',           min: 2600, modal: 2850, max: 3100 },
    { commodity: 'Cotton',    market: 'Yavatmal',     state: 'Maharashtra',     min: 6000, modal: 6500, max: 7000 },
    { commodity: 'Cotton',    market: 'Rajkot',       state: 'Gujarat',         min: 5800, modal: 6300, max: 6800 },
    { commodity: 'Chillies',  market: 'Guntur',       state: 'Andhra Pradesh',  min: 8000, modal: 10000,max: 13000},
    { commodity: 'Soybean',   market: 'Indore',       state: 'Madhya Pradesh',  min: 4200, modal: 4500, max: 4800 },
    { commodity: 'Maize',     market: 'Davangere',    state: 'Karnataka',       min: 1500, modal: 1700, max: 1900 },
    { commodity: 'Sugarcane', market: 'Kolhapur',     state: 'Maharashtra',     min: 280,  modal: 300,  max: 320  },
    { commodity: 'Groundnut', market: 'Rajkot',       state: 'Gujarat',         min: 5000, modal: 5500, max: 6000 },
    { commodity: 'Turmeric',  market: 'Nizamabad',    state: 'Telangana',       min: 7000, modal: 8000, max: 9000 },
    { commodity: 'Garlic',    market: 'Madhya Pradesh',state: 'Madhya Pradesh', min: 4000, modal: 5000, max: 6500 },
  ].map(r => ({
    id: `seed_${r.state}_${r.market}_${r.commodity}`.replace(/[^a-zA-Z0-9_-]/g, '_'),
    commodity: r.commodity,
    market: r.market,
    state: r.state,
    district: '',
    min_price: r.min,
    max_price: r.max,
    modal_price: r.modal,
    unit: 'quintal',
    arrival_date: today,
    source: 'seed_data',
  }));
}

// ─────────────────────────────────────────────────────────────
// MAIN: Try all sources in order, upsert to Supabase
// ─────────────────────────────────────────────────────────────
async function syncMarketPrices(state, commodity) {
  logger.info(`Syncing prices for state=${state} commodity=${commodity}`);
  let records = null;

  // Try Source 1: data.gov.in (with demo key)
  records = await fetchFromDataGovIn(state, commodity);

  // Try Source 2: eNAM
  if (!records?.length) {
    records = await fetchFromENAM(commodity);
  }

  // Try Source 3: Scraper
  if (!records?.length) {
    records = await fetchFromScraper(commodity, state);
  }

  // Fallback: seed data
  if (!records?.length) {
    logger.info('[Seed] Using curated seed price data');
    records = getSeedPrices();
    if (state && state !== 'all') records = records.filter(r => r.state === state);
    if (commodity) records = records.filter(r => r.commodity === commodity);
    if (!records.length) records = getSeedPrices(); // if filtered to nothing, use all
  }

  // Upsert to Supabase in batches
  const BATCH = 100;
  let total = 0;
  for (let i = 0; i < records.length; i += BATCH) {
    const batch = records.slice(i, i + BATCH);
    const { error } = await supabase.from('market_prices').upsert(batch, { onConflict: 'id' });
    if (error) logger.error('Supabase upsert error:', error.message);
    else total += batch.length;
  }
  logger.info(`Synced ${total} records to Supabase`);
  return total;
}

// ─────────────────────────────────────────────────────────────
// SEED initial data on first run
// ─────────────────────────────────────────────────────────────
async function seedInitialPrices() {
  try {
    // Check if we already have data
    const { count } = await supabase.from('market_prices').select('*', { count: 'exact', head: true });
    if (count > 0) {
      logger.info(`Supabase already has ${count} price records — skipping seed`);
      return;
    }
    logger.info('No prices in DB — seeding initial data...');
    const records = getSeedPrices();
    const { error } = await supabase.from('market_prices').upsert(records, { onConflict: 'id' });
    if (error) logger.error('Seed error:', error.message);
    else logger.info(`✅ Seeded ${records.length} initial price records`);
  } catch (err) {
    logger.error('Seed failed:', err.message);
  }
}

// Agmarknet returns arrival_date as DD/MM/YYYY — Supabase's arrival_date column expects ISO YYYY-MM-DD.
function parseAgmarknetDate(raw) {
  const today = new Date().toISOString().split('T')[0];
  if (!raw) return today;
  const parts = raw.split('/');
  if (parts.length !== 3) return today;
  const [day, month, year] = parts;
  return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
}

function normalizeRecord(r) {
  const isoDate = parseAgmarknetDate(r.arrival_date);
  return {
    id: `${r.state}_${r.market}_${r.commodity}_${isoDate}`.replace(/[^a-zA-Z0-9_-]/g, '_'),
    commodity: r.commodity,
    market: r.market,
    state: r.state,
    district: r.district || '',
    min_price: parseFloat(r.min_price) || 0,
    max_price: parseFloat(r.max_price) || 0,
    modal_price: parseFloat(r.modal_price) || 0,
    unit: 'quintal',
    arrival_date: isoDate,
    source: 'agmarknet',
  };
}

module.exports = { syncMarketPrices, seedInitialPrices, getSeedPrices };
