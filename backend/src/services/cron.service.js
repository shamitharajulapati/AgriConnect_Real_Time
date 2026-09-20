const cron = require('node-cron');
const { syncMarketPrices } = require('./market_price.service');
const logger = require('../config/logger');

const STATES = [
  'Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh',
  'Telangana', 'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan',
  'Gujarat', 'Madhya Pradesh', 'Delhi', 'West Bengal', 'Bihar',
];

// Every day at 8 AM IST (02:30 UTC)
cron.schedule('30 2 * * *', async () => {
  logger.info('=== Daily market price sync started ===');
  let total = 0;
  for (const state of STATES) {
    try {
      const count = await syncMarketPrices(state, null);
      total += count;
      // Respect rate limits
      await new Promise(r => setTimeout(r, 1000));
    } catch (err) {
      logger.error(`Sync failed for ${state}:`, err.message);
    }
  }
  logger.info(`=== Daily sync complete. Total: ${total} records ===`);
});

// Also sync every 6 hours for fresher data
cron.schedule('0 */6 * * *', async () => {
  logger.info('=== 6-hour price refresh ===');
  // Just sync top 5 states
  const topStates = ['Maharashtra', 'Punjab', 'Karnataka', 'Delhi', 'Uttar Pradesh'];
  for (const state of topStates) {
    await syncMarketPrices(state, null);
    await new Promise(r => setTimeout(r, 800));
  }
});

logger.info('Cron jobs initialized (daily sync + 6hr refresh)');
