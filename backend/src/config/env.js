const { z } = require('zod');

const envSchema = z.object({
  PORT: z.string().default('3000'),
  NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
  AGMARKNET_API_KEY: z.string().min(1).default('demo_key'),
  OPENWEATHER_KEY: z.string().min(1).default('demo_key'),
  ML_SERVICE_URL: z.string().url().default('http://localhost:5000'),
  ML_SERVICE_SECRET: z.string().min(8).default('dev_secret_key'),
  GOOGLE_MAPS_KEY: z.string().min(1).default('demo_key'),
  FIREBASE_PROJECT_ID: z.string().default('agri-connect-dev'),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success && process.env.NODE_ENV === 'production') {
  console.error('Invalid env vars:', parsed.error.format());
  process.exit(1);
}

module.exports = parsed.data ?? envSchema.parse({});
