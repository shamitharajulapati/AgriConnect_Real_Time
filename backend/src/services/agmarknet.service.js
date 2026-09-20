const axios = require('axios');
const supabase = require('../config/supabase');
const logger = require('../config/logger');

const BASE_URL = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';

async function syncPricesForState(state, commodity = null) {
  try {
    const params = {
      'api-key': process.env.AGMARKNET_API_KEY || 'demo',
      format: 'json',
      limit: 500,
      offset: 0,
    };
    if (state) params['filters[state]'] = state;
    if (commodity) params['filters[commodity]'] = commodity;

    const res = await axios.get(BASE_URL, { params, timeout: 15000 });
    const records = res.data?.records ?? [];
    if (!records.length) return 0;

    const BATCH = 100;
    let written = 0;
    for (let i = 0; i < records.length; i += BATCH) {
      const batch = records.slice(i, i + BATCH).map(r => {
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
      });

      const { error } = await supabase.from('market_prices').upsert(batch, { onConflict: 'id' });
      if (error) logger.error('Supabase upsert error:', error.message);
      else written += batch.length;
    }
    logger.info(`Synced ${written} records for ${state}`);
    return written;
  } catch (err) {
    logger.error(`Agmarknet sync failed for ${state}:`, err.message);
    return 0;
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

module.exports = { syncPricesForState };
