require('dotenv').config();

const STATES = [
  'Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh',
  'Telangana', 'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan',
  'Gujarat', 'Kerala', 'West Bengal', 'Bihar',
];

const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function indiaDateDaysAgo(daysAgo) {
  const date = new Date(Date.now() - daysAgo * 86400000);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

async function main() {
  const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY'];
  const missing = required.filter(name => !process.env[name]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const { syncMarketPrices } = require('../services/market_price.service');
  let total = 0;
  let failures = 0;
  const backfill = process.env.BACKFILL_HISTORY === 'true';

  if (backfill) {
    // The public Agmarknet mirror retains at most the most recent 30 days.
    // Fetch each state/date pair explicitly so older daily observations are
    // not lost by the normal latest-day sync.
    const days = Math.min(30, Math.max(1, Number(process.env.HISTORY_DAYS) || 30));
    for (let daysAgo = days - 1; daysAgo >= 0; daysAgo -= 1) {
      const date = indiaDateDaysAgo(daysAgo);
      for (const state of STATES) {
        try {
          const count = await syncMarketPrices(state, null, date);
          total += count;
          console.log(`[History backfill] ${date} / ${state}: ${count} records saved`);
        } catch (error) {
          failures += 1;
          console.error(`[History backfill] ${date} / ${state} failed: ${error.message}`);
        }
        await wait(150);
      }
    }

    console.log(`[History backfill] Complete: ${total} records saved across ${days} days and ${STATES.length} states`);
    if (failures) throw new Error(`${failures} state/date sync(s) failed; see logs above`);
    if (total === 0) throw new Error('No historical market-price records were saved.');
    return;
  }

  for (const state of STATES) {
    try {
      const count = await syncMarketPrices(state, null);
      total += count;
      console.log(`[Scheduled sync] ${state}: ${count} records saved`);
    } catch (error) {
      failures += 1;
      console.error(`[Scheduled sync] ${state} failed: ${error.message}`);
    }
    await wait(1000);
  }

  console.log(`[Scheduled sync] Complete: ${total} records saved across ${STATES.length} states`);
  if (failures) {
    throw new Error(`${failures} state sync(s) failed; see logs above`);
  }
  if (total === 0) {
    throw new Error('No live market-price records were saved. Check the market-data source availability and filters.');
  }
}

main().catch(error => {
  console.error(`[Scheduled sync] Fatal error: ${error.message}`);
  process.exitCode = 1;
});
