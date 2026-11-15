-- One-time setup for a six-hourly cloud-side market-price sync.
-- Before running this file:
--   1. Enable pg_cron and pg_net in Supabase Database > Extensions.
--   2. Create the three Vault secrets below, using your own values.
--   3. Deploy the sync-market-prices Edge Function and set its AGMARKNET_KEY
--      and CRON_SECRET secrets in Supabase Edge Function Secrets.
--
-- Never commit actual API keys or cron secrets into this file.

-- Create these in Vault (replace placeholder values before running):
-- select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'agri_market_sync_project_url');
-- select vault.create_secret('YOUR_SUPABASE_ANON_KEY', 'agri_market_sync_anon_key');
-- select vault.create_secret('YOUR_RANDOM_CRON_SECRET', 'agri_market_sync_cron_secret');

select cron.unschedule(jobid)
from cron.job
where jobname = 'agriconnect-market-price-sync';

select cron.schedule(
  'agriconnect-market-price-sync',
  '0 */6 * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret
              from vault.decrypted_secrets
              where name = 'agri_market_sync_project_url')
             || '/functions/v1/sync-market-prices',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (select decrypted_secret
                   from vault.decrypted_secrets
                   where name = 'agri_market_sync_anon_key'),
        'x-cron-secret', (select decrypted_secret
                          from vault.decrypted_secrets
                          where name = 'agri_market_sync_cron_secret')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);
