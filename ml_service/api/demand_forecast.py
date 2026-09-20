import numpy as np
from datetime import datetime

DEMAND_PROFILES = {
    'Tomato': {'base': 0.72, 'trend': 'RISING', 'peak_days': 7},
    'Onion': {'base': 0.45, 'trend': 'FALLING', 'peak_days': 15},
    'Potato': {'base': 0.60, 'trend': 'STABLE', 'peak_days': 10},
    'Wheat': {'base': 0.80, 'trend': 'RISING', 'peak_days': 5},
    'Rice': {'base': 0.70, 'trend': 'STABLE', 'peak_days': 8},
    'Cotton': {'base': 0.55, 'trend': 'RISING', 'peak_days': 12},
}

REGIONS = ['Maharashtra', 'Karnataka', 'Delhi NCR', 'Tamil Nadu', 'Gujarat']


def forecast_demand(commodity: str, state: str = None) -> dict:
    profile = DEMAND_PROFILES.get(commodity, {'base': 0.50, 'trend': 'STABLE', 'peak_days': 10})
    rng = np.random.default_rng(hash(commodity or 'x') % 2**32)
    idx = profile['base'] + rng.random() * 0.1

    weekly_base = 35.0 + profile['base'] * 60
    weekly_demand = [round(float(weekly_base + rng.random() * 30 - 15), 1) for _ in range(7)]

    regions = [
        {'region': r, 'demand': round(float(0.3 + rng.random() * 0.65), 3)}
        for r in REGIONS
    ]

    return {
        'commodity': commodity,
        'state': state,
        'demandLevel': 'HIGH' if idx > 0.7 else 'MEDIUM' if idx > 0.4 else 'LOW',
        'demandIndex': round(float(idx), 3),
        'trend': profile['trend'],
        'peakExpectedDays': profile['peak_days'],
        'weeklyDemand': weekly_demand,
        'regions': regions,
        'generatedAt': datetime.now().isoformat(),
    }
