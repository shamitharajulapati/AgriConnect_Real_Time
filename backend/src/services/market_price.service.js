require('dotenv').config();
const axios = require('axios');
const supabase = require('../config/supabase');
const logger = require('../config/logger');

// ─────────────────────────────────────────────────────────────
// SOURCE 1: data.gov.in Agmarknet variety-wise daily market prices
// ─────────────────────────────────────────────────────────────
const AGMARKNET_URL = 'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

async function fetchFromDataGovIn(state, commodity) {
  try {
    const params = {
      'api-key': process.env.AGMARKNET_KEY,
      format: 'json',
      limit: 1000,
      offset: 0,
      'sort[Arrival_Date]': 'desc',
    };
    if (state) params['filters[State]'] = state;
    if (commodity) params['filters[Commodity]'] = commodity;

    // The provider can respond slowly from hosted runners; allow enough time
    // for its 1,000-row response before falling back to another source.
    const res = await axios.get(AGMARKNET_URL, { params, timeout: 45000 });
    const records = res.data?.records ?? [];
    logger.info(`[DataGovIn] Fetched ${records.length} records for ${state}`);
    return records.map(normalizeRecord).filter(Boolean);
  } catch (err) {
    const detail = err.response?.data?.error || err.response?.data?.message || err.message;
    logger.warn(`[DataGovIn] Failed: ${detail}`);
    return null; // trigger fallback
  }
}

// ─────────────────────────────────────────────────────────────
// SOURCE 2: eNAM API (National Agriculture Market — no key)
// ─────────────────────────────────────────────────────────────
const ENAM_URL = 'https://enam.gov.in/web/dashboard_annexure/trade_data';
const MANDI_API_URL = 'https://api.dharun.dev/v1/mandi';

// Public cached mirror of Agmarknet. It refreshes the official data.gov.in
// feed every few hours and avoids the intermittent timeouts from GitHub runners.
async function fetchFromMandiApi(state, commodity, date) {
  try {
    const res = await axios.get(MANDI_API_URL, {
      params: { state, commodity: commodity || undefined, date: date || undefined, limit: 1000 },
      timeout: 20000,
      headers: { Accept: 'application/json' },
    });
    const records = res.data?.data ?? [];
    logger.info(`[Mandi API] Fetched ${records.length} records for ${state}${date ? ` on ${date}` : ''}`);
    return records.map(normalizeRecord).filter(Boolean);
  } catch (err) {
    const detail = err.response?.data?.error?.message || err.response?.data?.message || err.message;
    logger.warn(`[Mandi API] Failed: ${detail}`);
    return null;
  }
}

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
// MAIN: Try all sources in order, upsert to Supabase
// ─────────────────────────────────────────────────────────────
async function syncMarketPrices(state, commodity, date) {
  logger.info(`Syncing prices for state=${state} commodity=${commodity} date=${date || 'latest'}`);
  let records = null;

  // Try the cached Agmarknet mirror first. It returns current rows without
  // requiring a key and is reachable from GitHub-hosted runners.
  records = await fetchFromMandiApi(state, commodity, date);

  // Keep the existing providers as fallbacks when the mirror is unavailable.
  if (!date && !records?.length && process.env.AGMARKNET_KEY) {
    records = await fetchFromDataGovIn(state, commodity);
  }

  // Try eNAM if the mirror and optional data.gov.in fallback have no rows.
  if (!date && !records?.length) {
    records = await fetchFromENAM(commodity);
  }

  // eNAM can ignore state filters; apply both requested filters to every
  // source before saving anything.
  records = (records || []).filter(record => {
    const stateMatches = !state || state.toLowerCase() === 'all' ||
      String(record.state || '').trim().toLowerCase() === state.trim().toLowerCase();
    const commodityMatches = !commodity ||
      String(record.commodity || '').trim().toLowerCase() === commodity.trim().toLowerCase();
    const dateMatches = !date || record.arrival_date === date;
    return stateMatches && commodityMatches && dateMatches;
  });

  // Do not insert synthetic seed prices when live sources return no rows.
  if (!records?.length) {
    logger.warn('[Market] No live price records found; skipping sync instead of inserting sample prices.');
    return 0;
  }

  // A source response can contain repeated market/commodity/date rows. Since
  // those normalize to the same ID, PostgreSQL rejects a single upsert batch
  // that contains the same conflict key more than once. Keep the last source
  // row for each ID before batching.
  const recordsWithId = records.filter(record => record.id);
  const uniqueRecords = Array.from(
    new Map(recordsWithId.map(record => [record.id, record])).values(),
  );
  const duplicateCount = recordsWithId.length - uniqueRecords.length;
  const missingIdCount = records.length - recordsWithId.length;
  if (duplicateCount > 0) {
    logger.warn(`[Market] Removed ${duplicateCount} duplicate records before Supabase upsert`);
  }
  if (missingIdCount > 0) {
    logger.warn(`[Market] Skipped ${missingIdCount} records without IDs`);
  }
  if (uniqueRecords.length === 0) {
    logger.warn('[Market] No records with valid IDs remained after deduplication.');
    return 0;
  }

  // Upsert to Supabase in batches
  const BATCH = 100;
  let total = 0;
  let failedBatches = 0;
  for (let i = 0; i < uniqueRecords.length; i += BATCH) {
    const batch = uniqueRecords.slice(i, i + BATCH);
    const { error } = await supabase.from('market_prices').upsert(batch, { onConflict: 'id' });
    if (error) {
      failedBatches += 1;
      const reason = [error.code, error.message, error.details, error.hint]
        .filter(Boolean)
        .join(' | ');
      logger.error(`Supabase upsert failed for ${state} (batch ${i + 1}-${i + batch.length}): ${reason || JSON.stringify(error)}`);
    } else {
      total += batch.length;
    }
  }
  logger.info(`Synced ${total} records to Supabase`);
  if (failedBatches > 0) {
    throw new Error(`${failedBatches} Supabase upsert batch(es) failed for ${state}; ${total} records were saved`);
  }
  return total;
}

// ─────────────────────────────────────────────────────────────
// Agmarknet returns arrival_date as DD/MM/YYYY — Supabase's arrival_date column expects ISO YYYY-MM-DD.
function parseAgmarknetDate(raw) {
  if (typeof raw !== 'string') return null;
  const value = raw.trim();
  const isoMatch = value.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  const slashMatch = value.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!isoMatch && !slashMatch) return null;
  const yearText = isoMatch ? isoMatch[1] : slashMatch[3];
  const monthText = isoMatch ? isoMatch[2] : slashMatch[2];
  const dayText = isoMatch ? isoMatch[3] : slashMatch[1];
  const day = Number(dayText);
  const month = Number(monthText);
  const year = Number(yearText);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return `${yearText}-${monthText.padStart(2, '0')}-${dayText.padStart(2, '0')}`;
}

function normalizeRecord(r) {
  const isoDate = parseAgmarknetDate(r.arrival_date ?? r.Arrival_Date ?? r.date);
  if (!isoDate) return null;
  return {
    id: `${r.State ?? r.state}_${r.Market ?? r.market}_${r.Commodity ?? r.commodity}_${r.Variety ?? r.variety ?? ''}_${r.Grade ?? r.grade ?? ''}_${isoDate}`.replace(/[^a-zA-Z0-9_-]/g, '_'),
    commodity: r.Commodity ?? r.commodity,
    market: r.Market ?? r.market,
    state: r.State ?? r.state,
    district: r.District ?? r.district ?? '',
    min_price: parseFloat(r.Min_Price ?? r.min_price) || 0,
    max_price: parseFloat(r.Max_Price ?? r.max_price) || 0,
    modal_price: parseFloat(r.Modal_Price ?? r.modal_price) || 0,
    unit: 'quintal',
    arrival_date: isoDate,
    source: r.source?.name || 'agmarknet',
  };
}

module.exports = { syncMarketPrices };
