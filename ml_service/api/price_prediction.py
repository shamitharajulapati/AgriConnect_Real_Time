import numpy as np
from datetime import datetime, timedelta
import os
import requests

BASE_PRICES = {
    'Tomato': 1500, 'Onion': 950, 'Potato': 750, 'Wheat': 2250,
    'Rice': 3000, 'Cotton': 6500, 'Chillies': 10000, 'Soybean': 4500,
}

def predict(params: dict) -> dict:
    commodity = params.get('commodity', 'Tomato')
    state = params.get('state', 'Karnataka')
    horizon = int(params.get('days', 7))

    url = os.getenv('SUPABASE_URL', '').rstrip('/')
    key = os.getenv('SUPABASE_ANON_KEY', '')
    if not url or not key:
        raise RuntimeError('Supabase market data is not configured for live forecasts.')

    def fetch_rows(filter_state):
        filters = {
            'select': 'arrival_date,modal_price',
            'commodity': f'eq.{commodity}',
            # Read the newest observations first so large historical tables do
            # not cause the row limit to hide the latest market price.
            'order': 'arrival_date.desc',
            'limit': '500',
        }
        if filter_state and filter_state != 'All States':
            filters['state'] = f'eq.{filter_state}'
        response = requests.get(
            f'{url}/rest/v1/market_prices',
            params=filters,
            headers={'apikey': key, 'Authorization': f'Bearer {key}'},
            timeout=12,
        )
        response.raise_for_status()
        return response.json()

    records = fetch_rows(state)
    forecast_market = state
    if not records and state != 'All States':
        records = fetch_rows('All States')
        forecast_market = 'India'
    if not records:
        raise RuntimeError(f'No Agmarknet price history is available for {commodity}.')

    by_date = {}
    for row in records:
        try:
            observed_date = datetime.strptime(row['arrival_date'][:10], '%Y-%m-%d').date()
            observed_price = float(row['modal_price'])
        except (KeyError, TypeError, ValueError):
            continue
        if observed_price > 0:
            bucket = by_date.setdefault(observed_date, [])
            bucket.append(observed_price)
    if not by_date:
        raise RuntimeError(f'No valid Agmarknet price history is available for {commodity}.')

    latest_date = max(by_date)
    # Use the observations that are actually stored. A source can go quiet for
    # days; that should not make the module disappear. With one observed date
    # this is a reference estimate, not a learned trend.
    series = sorted((day, float(np.mean(prices))) for day, prices in by_date.items())[-30:]
    current_price = series[-1][1]
    x = np.array([(day - series[0][0]).days for day, _ in series], dtype=float)
    y = np.array([price for _, price in series], dtype=float)
    slope = float(np.polyfit(x, y, 1)[0]) if len(series) > 1 and np.ptp(x) > 0 else 0.0
    daily_change = float(np.clip(slope / current_price, -0.02, 0.02))
    changes = []
    for (day_a, price_a), (day_b, price_b) in zip(series, series[1:]):
        gap = max(1, (day_b - day_a).days)
        changes.append((price_b / price_a) ** (1 / gap) - 1)
    volatility = float(np.std(changes)) if len(changes) > 1 else 0.02

    points = []
    for index in range(1, horizon + 1):
        price = current_price * ((1 + daily_change) ** index)
        uncertainty = min(0.25, max(0.02, volatility * np.sqrt(index) * 1.65))
        forecast_date = datetime.now() + timedelta(days=index)
        points.append({
            'date': forecast_date.strftime('%Y-%m-%d'),
            'price': round(float(price), 2),
            'lowerBound': round(float(price * (1 - uncertainty)), 2),
            'upperBound': round(float(price * (1 + uncertainty)), 2),
        })

    confidence = min(0.82, 0.48 + len(series) * 0.012) if len(series) > 1 else 0.20
    return {
        'commodity': commodity, 'state': forecast_market, 'points': points,
        'currentPrice': round(current_price, 2),
        'confidence': round(confidence, 3), 'unit': 'INR/quintal',
        'dataSource': 'Agmarknet', 'lastObservedDate': latest_date.isoformat(),
        'estimateOnly': len(series) < 2,
        'generatedAt': datetime.now().isoformat(),
    }
