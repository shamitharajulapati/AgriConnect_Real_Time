require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const { createServer } = require('http');

const app = express();
const server = createServer(app);

// Middleware
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// Health check
app.get('/health', (_, res) => res.json({ status: 'ok', service: 'agriconnect-backend', version: '2.0.0' }));

// Routes
app.use('/api/auth', require('./src/routes/auth'));
app.use('/api/market', require('./src/routes/market'));
app.use('/api/crops', require('./src/routes/crops'));
app.use('/api/ml', require('./src/routes/ml'));
app.use('/api/alerts', require('./src/routes/alerts'));
app.use('/api/chat', require('./src/routes/chat'));
app.use('/api/voice', require('./src/routes/voice'));

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// Start
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`AgriConnect backend running on port ${PORT}`));

// Start cron jobs + seed initial data
if (process.env.NODE_ENV !== 'test') {
  require('./src/services/cron.service');
  // Seed prices on startup if Supabase is empty
  const { seedInitialPrices } = require('./src/services/market_price.service');
  seedInitialPrices().catch(console.error);
}

module.exports = app;
