"""
Run this once to seed real market prices into Supabase.
Usage: python seed_supabase.py
"""
import os
import _env
import requests
from datetime import datetime, timedelta
import random

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]  # service_role key — keep out of source control

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

# Real market prices (INR/quintal) - current approximate values
PRICES = [
    # Tomato
    ("Tomato", "Azadpur", "Delhi",          1000, 2000, 1500),
    ("Tomato", "Kolar", "Karnataka",         800, 1600, 1300),
    ("Tomato", "Nashik", "Maharashtra",      900, 1700, 1200),
    ("Tomato", "Madanapalle", "Andhra Pradesh", 700, 1500, 1100),
    ("Tomato", "Hosur", "Tamil Nadu",        850, 1650, 1250),
    # Onion
    ("Onion", "Lasalgaon", "Maharashtra",    600, 1200, 950),
    ("Onion", "Nashik", "Maharashtra",       550, 1100, 880),
    ("Onion", "Azadpur", "Delhi",            750, 1400, 1050),
    ("Onion", "Bengaluru", "Karnataka",      700, 1300, 1000),
    ("Onion", "Hubli", "Karnataka",          620, 1150, 900),
    # Potato
    ("Potato", "Agra", "Uttar Pradesh",      500, 900, 750),
    ("Potato", "Kolkata", "West Bengal",     520, 950, 780),
    ("Potato", "Azadpur", "Delhi",           600, 1000, 830),
    ("Potato", "Indore", "Madhya Pradesh",   480, 880, 720),
    # Wheat
    ("Wheat", "Chandigarh", "Punjab",       2100, 2400, 2250),
    ("Wheat", "Ludhiana", "Punjab",         2050, 2350, 2200),
    ("Wheat", "Indore", "Madhya Pradesh",   2000, 2300, 2150),
    ("Wheat", "Agra", "Uttar Pradesh",      2000, 2280, 2130),
    ("Wheat", "Jaipur", "Rajasthan",        1980, 2250, 2100),
    # Rice
    ("Rice", "Amritsar", "Punjab",          2800, 3200, 3000),
    ("Rice", "Patna", "Bihar",              2600, 3100, 2850),
    ("Rice", "Kolkata", "West Bengal",      2700, 3100, 2900),
    ("Rice", "Hyderabad", "Telangana",      2800, 3200, 3000),
    # Cotton
    ("Cotton", "Yavatmal", "Maharashtra",   6000, 7000, 6500),
    ("Cotton", "Rajkot", "Gujarat",         5800, 6800, 6300),
    ("Cotton", "Adilabad", "Telangana",     5900, 6900, 6400),
    # Chillies
    ("Chillies", "Guntur", "Andhra Pradesh", 8000, 13000, 10000),
    ("Chillies", "Warangal", "Telangana",    7500, 12000, 9500),
    # Soybean
    ("Soybean", "Indore", "Madhya Pradesh", 4200, 4800, 4500),
    ("Soybean", "Latur", "Maharashtra",     4100, 4700, 4400),
    # Maize
    ("Maize", "Davangere", "Karnataka",     1500, 1900, 1700),
    ("Maize", "Nizamabad", "Telangana",     1600, 2000, 1800),
    # Sugarcane
    ("Sugarcane", "Kolhapur", "Maharashtra", 280, 320, 300),
    ("Sugarcane", "Muzaffarnagar", "Uttar Pradesh", 310, 350, 325),
    # Groundnut
    ("Groundnut", "Rajkot", "Gujarat",      5000, 6000, 5500),
    ("Groundnut", "Kurnool", "Andhra Pradesh", 5200, 6200, 5700),
    # Turmeric
    ("Turmeric", "Nizamabad", "Telangana",  7000, 9000, 8000),
    ("Turmeric", "Sangli", "Maharashtra",   7500, 9500, 8500),
    # Garlic
    ("Garlic", "Indore", "Madhya Pradesh",  4000, 6500, 5200),
    ("Garlic", "Ratlam", "Madhya Pradesh",  3800, 6200, 5000),
]

# Real district for each mandi town above — used to prioritize a farmer's
# local market in the app (state alone isn't enough to group by).
MARKET_DISTRICT = {
    "Guntur": "Guntur", "Kurnool": "Kurnool", "Madanapalle": "Annamayya",
    "Patna": "Patna", "Azadpur": "North Delhi", "Rajkot": "Rajkot",
    "Davangere": "Davanagere", "Hubli": "Dharwad", "Bengaluru": "Bengaluru Urban",
    "Kolar": "Kolar", "Ratlam": "Ratlam", "Indore": "Indore",
    "Yavatmal": "Yavatmal", "Lasalgaon": "Nashik", "Nashik": "Nashik",
    "Latur": "Latur", "Kolhapur": "Kolhapur", "Sangli": "Sangli",
    "Amritsar": "Amritsar", "Chandigarh": "Sahibzada Ajit Singh Nagar",
    "Ludhiana": "Ludhiana", "Jaipur": "Jaipur", "Hosur": "Krishnagiri",
    "Warangal": "Warangal", "Adilabad": "Adilabad", "Nizamabad": "Nizamabad",
    "Hyderabad": "Hyderabad", "Agra": "Agra", "Muzaffarnagar": "Muzaffarnagar",
    "Kolkata": "Kolkata",
}

def seed_prices():
    today = datetime.now().strftime('%Y-%m-%d')
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')

    records = []
    for i, (commodity, market, state, min_p, max_p, modal_p) in enumerate(PRICES):
        # Add slight random variation
        variance = random.uniform(0.95, 1.05)
        for date in [today, yesterday]:
            modal = round(modal_p * variance)
            records.append({
                "id": f"seed_{state}_{market}_{commodity}_{date}".replace(" ", "_").replace(",", ""),
                "commodity": commodity,
                "market": market,
                "state": state,
                "district": MARKET_DISTRICT.get(market, ""),
                "min_price": round(min_p * variance),
                "max_price": round(max_p * variance),
                "modal_price": modal,
                "unit": "quintal",
                "arrival_date": date,
                "source": "curated_data"
            })

    # Upsert in batches of 50
    batch_size = 50
    total = 0
    for i in range(0, len(records), batch_size):
        batch = records[i:i+batch_size]
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/market_prices",
            headers=HEADERS,
            json=batch
        )
        if resp.status_code in (200, 201):
            total += len(batch)
            print(f"[OK] Inserted batch {i//batch_size + 1}: {len(batch)} records")
        else:
            print(f"[ERR] Error: {resp.status_code} - {resp.text[:200]}")

    print(f"\nDone! Seeded {total} price records into Supabase")
    print(f"   Commodities: {len(set(r['commodity'] for r in records))}")
    print(f"   States: {len(set(r['state'] for r in records))}")
    print(f"   Markets: {len(set(r['market'] for r in records))}")

if __name__ == '__main__':
    print("Seeding market prices into Supabase...")
    seed_prices()
