"""
Anchor prices per (commodity, state), mirroring the curated dataset seeded into
Supabase (see /seed_supabase.py at the repo root). Used to generate a realistic
synthetic daily price history for ARIMA training, since the live Agmarknet/eNAM
sync is not yet wired in (see AgriConnect_EPICS_Review1_Updated_1.pptx, slide 4:
"Out of Scope (Future): Live Agmarknet/eNAM API sync").
"""
import numpy as np
import pandas as pd
from collections import defaultdict

# (commodity, market, state, min_price, max_price, modal_price)
SEED_PRICES = [
    ("Tomato", "Azadpur", "Delhi", 1000, 2000, 1500),
    ("Tomato", "Kolar", "Karnataka", 800, 1600, 1300),
    ("Tomato", "Nashik", "Maharashtra", 900, 1700, 1200),
    ("Tomato", "Madanapalle", "Andhra Pradesh", 700, 1500, 1100),
    ("Tomato", "Hosur", "Tamil Nadu", 850, 1650, 1250),
    ("Onion", "Lasalgaon", "Maharashtra", 600, 1200, 950),
    ("Onion", "Nashik", "Maharashtra", 550, 1100, 880),
    ("Onion", "Azadpur", "Delhi", 750, 1400, 1050),
    ("Onion", "Bengaluru", "Karnataka", 700, 1300, 1000),
    ("Onion", "Hubli", "Karnataka", 620, 1150, 900),
    ("Potato", "Agra", "Uttar Pradesh", 500, 900, 750),
    ("Potato", "Kolkata", "West Bengal", 520, 950, 780),
    ("Potato", "Azadpur", "Delhi", 600, 1000, 830),
    ("Potato", "Indore", "Madhya Pradesh", 480, 880, 720),
    ("Wheat", "Chandigarh", "Punjab", 2100, 2400, 2250),
    ("Wheat", "Ludhiana", "Punjab", 2050, 2350, 2200),
    ("Wheat", "Indore", "Madhya Pradesh", 2000, 2300, 2150),
    ("Wheat", "Agra", "Uttar Pradesh", 2000, 2280, 2130),
    ("Wheat", "Jaipur", "Rajasthan", 1980, 2250, 2100),
    ("Rice", "Amritsar", "Punjab", 2800, 3200, 3000),
    ("Rice", "Patna", "Bihar", 2600, 3100, 2850),
    ("Rice", "Kolkata", "West Bengal", 2700, 3100, 2900),
    ("Rice", "Hyderabad", "Telangana", 2800, 3200, 3000),
    ("Cotton", "Yavatmal", "Maharashtra", 6000, 7000, 6500),
    ("Cotton", "Rajkot", "Gujarat", 5800, 6800, 6300),
    ("Cotton", "Adilabad", "Telangana", 5900, 6900, 6400),
    ("Chillies", "Guntur", "Andhra Pradesh", 8000, 13000, 10000),
    ("Chillies", "Warangal", "Telangana", 7500, 12000, 9500),
    ("Soybean", "Indore", "Madhya Pradesh", 4200, 4800, 4500),
    ("Soybean", "Latur", "Maharashtra", 4100, 4700, 4400),
]

# (commodity, state) -> mean modal price, averaged across markets in that state
_grouped = defaultdict(list)
for commodity, market, state, min_p, max_p, modal_p in SEED_PRICES:
    _grouped[(commodity, state)].append(modal_p)

ANCHOR_PRICES = {k: float(np.mean(v)) for k, v in _grouped.items()}


def generate_history(commodity: str, state: str, anchor_price: float, days: int = 200) -> pd.Series:
    """Synthetic daily price series: mild trend + weekly/seasonal cycles + noise,
    deterministic per (commodity, state) so retraining is reproducible."""
    seed = abs(hash(f"{commodity}_{state}")) % (2**32)
    rng = np.random.default_rng(seed)

    t = np.arange(days)
    trend = anchor_price * (0.0002 * t)                                  # slow upward drift
    weekly = anchor_price * 0.02 * np.sin(2 * np.pi * t / 7)             # mandi weekly cycle
    seasonal = anchor_price * 0.06 * np.sin(2 * np.pi * t / 90)          # seasonal arrivals cycle
    noise = rng.normal(0, anchor_price * 0.025, size=days)

    prices = anchor_price + trend + weekly + seasonal + noise
    prices = np.clip(prices, anchor_price * 0.5, anchor_price * 1.8)

    end = pd.Timestamp.now().normalize()
    idx = pd.date_range(end=end, periods=days, freq='D')
    return pd.Series(prices, index=idx, name='price')
