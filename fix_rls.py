import os, _env, requests, sys
sys.stdout.reconfigure(encoding='utf-8')

# NOTE: this script only verifies data via the service key (which bypasses RLS) —
# it does not itself change any RLS policy. The actual policy fix is
# supabase_rls_policies.sql — run that in the Supabase SQL Editor.
SUPABASE_URL = os.environ["SUPABASE_URL"]
SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
H = {'apikey': SERVICE_KEY, 'Authorization': 'Bearer ' + SERVICE_KEY}

# Verify using service key (bypasses RLS)
r = requests.get(
    f'{SUPABASE_URL}/rest/v1/market_prices',
    headers=H,
    params={'select': 'commodity,market,state,modal_price', 'limit': 10, 'order': 'modal_price.desc'}
)
data = r.json()
print("Records in Supabase (via service key):", len(data))
for p in data[:5]:
    print(f"  {p['commodity']:12} | {p['market']:20} | Rs.{p['modal_price']}")

print("\nNote: Logged-in users can read this data via the Flutter app.")
print("Market prices are accessible when authenticated with Supabase.")
