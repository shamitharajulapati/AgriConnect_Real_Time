import os, _env, requests, sys
sys.stdout.reconfigure(encoding='utf-8')

URL = os.environ["SUPABASE_URL"] + '/rest/v1/market_prices'
KEY = os.environ["SUPABASE_ANON_KEY"]
H = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY}

r = requests.get(URL, headers=H, params={
    'select': 'commodity,market,state,modal_price',
    'limit': 10,
    'order': 'modal_price.desc'
})

data = r.json()
print("Records in Supabase:", len(data))
print("-" * 50)
for p in data:
    print(f"{p['commodity']:12} | {p['market']:20} | Rs.{p['modal_price']}")
