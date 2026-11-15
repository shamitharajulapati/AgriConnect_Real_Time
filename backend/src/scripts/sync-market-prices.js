require('dotenv').config();

const STATES = [
  'Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh',
  'Telangana', 'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan',
  'Gujarat', 'Madhya Pradesh', 'Delhi', 'West Bengal', 'Bihar',
];

const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

async function main() {
  const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'AGMARKNET_KEY'];
  const missing = required.filter(name => !process.env[name]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const { syncMarketPrices } = require('../services/market_price.service');
  let total = 0;
  let failures = 0;

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
}

main().catch(error => {
  console.error(`[Scheduled sync] Fatal error: ${error.message}`);
  process.exitCode = 1;
});
