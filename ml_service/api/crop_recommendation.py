"""Explainable crop screening with ecology rules and an optional market signal.

The compact profiles are bundled first-pass screening bands, not a live query
to FAO EcoCrop or GAEZ and not location-calibrated extension recommendations.
Their shape follows the EcoCrop idea of comparing soil and climate constraints;
final choices should be checked against local KVK/ICAR advice and the farmer's
irrigation, variety, and soil-test data.
"""

import os
from datetime import datetime, timezone

import requests

# Rainfall bands here are seasonal planning bands in mm to match the app input.
# EcoCrop publishes annual ecological ranges, so those values must not be
# compared directly to the app's seasonal estimate.
CROP_DB = [
    {'name': 'Tomato', 'emoji': '🍅', 'soils': ['Loamy', 'Sandy', 'Silt'], 'seasons': ['Kharif', 'Rabi'], 'temp_opt': (18, 27), 'temp_abs': (10, 35), 'rain_opt': (600, 1000), 'rain_abs': (400, 1200), 'duration': '90-120 days', 'water': 'Medium'},
    {'name': 'Wheat', 'emoji': '🌾', 'soils': ['Loamy', 'Clay', 'Silt'], 'seasons': ['Rabi'], 'temp_opt': (10, 22), 'temp_abs': (5, 30), 'rain_opt': (450, 650), 'rain_abs': (300, 900), 'duration': '110-130 days', 'water': 'Medium'},
    {'name': 'Rice', 'emoji': '🌾', 'soils': ['Clay', 'Silt'], 'seasons': ['Kharif', 'Rabi'], 'temp_opt': (20, 30), 'temp_abs': (10, 36), 'rain_opt': (1000, 2000), 'rain_abs': (600, 4000), 'duration': '120-150 days', 'water': 'High'},
    {'name': 'Cotton', 'emoji': '🌿', 'soils': ['Black Cotton', 'Loamy'], 'seasons': ['Kharif'], 'temp_opt': (21, 32), 'temp_abs': (15, 37), 'rain_opt': (500, 850), 'rain_abs': (300, 1200), 'duration': '150-180 days', 'water': 'Medium'},
    {'name': 'Soybean', 'emoji': '🫘', 'soils': ['Loamy', 'Black Cotton'], 'seasons': ['Kharif'], 'temp_opt': (20, 30), 'temp_abs': (15, 35), 'rain_opt': (600, 1000), 'rain_abs': (400, 1300), 'duration': '90-100 days', 'water': 'Medium'},
    {'name': 'Maize', 'emoji': '🌽', 'soils': ['Sandy', 'Loamy', 'Silt'], 'seasons': ['Kharif', 'Rabi', 'Zaid'], 'temp_opt': (18, 30), 'temp_abs': (10, 35), 'rain_opt': (500, 900), 'rain_abs': (300, 1200), 'duration': '80-110 days', 'water': 'Medium'},
    {'name': 'Onion', 'emoji': '🧅', 'soils': ['Sandy', 'Loamy'], 'seasons': ['Rabi', 'Zaid'], 'temp_opt': (13, 24), 'temp_abs': (5, 32), 'rain_opt': (400, 700), 'rain_abs': (250, 1000), 'duration': '100-120 days', 'water': 'Low'},
    {'name': 'Chillies', 'emoji': '🌶️', 'soils': ['Loamy', 'Sandy', 'Silt'], 'seasons': ['Kharif', 'Rabi'], 'temp_opt': (20, 30), 'temp_abs': (15, 35), 'rain_opt': (600, 1000), 'rain_abs': (400, 1400), 'duration': '150-180 days', 'water': 'Medium'},
]

ALIASES = {
    'chillies': ('chilli', 'chili', 'chilis', 'green chilli', 'dry chilli'),
    'rice': ('paddy',),
    'soybean': ('soyabean',),
}


def _normalize(value: str) -> str:
    return ' '.join(str(value or '').strip().lower().split())


def _range_fit(value: float, optimal: tuple[float, float], absolute: tuple[float, float]) -> float:
    """Return 1 in the optimal band, taper to 0 at absolute limits."""
    opt_min, opt_max = optimal
    abs_min, abs_max = absolute
    if value < abs_min or value > abs_max:
        return 0.0
    if opt_min <= value <= opt_max:
        return 1.0
    if value < opt_min:
        width = opt_min - abs_min
        return (value - abs_min) / width if width else 1.0
    width = abs_max - opt_max
    return (abs_max - value) / width if width else 1.0


def _current_market_prices(state: str, district: str = '') -> tuple[dict, dict, dict]:
    """Get fresh prices when configured; no price data must not block agronomy."""
    url = os.getenv('SUPABASE_URL', '').rstrip('/')
    key = os.getenv('SUPABASE_ANON_KEY', '')
    if not url or not key:
        return {}, {}, {}

    def fetch(filter_state='', filter_district=''):
        query = {
            'select': 'commodity,state,district,modal_price,arrival_date,source',
            'order': 'arrival_date.desc',
            'limit': '5000',
            'source': 'not.in.(seed_data,demo_data)',
        }
        if filter_state and filter_state != 'All States':
            query['state'] = f'eq.{filter_state}'
        if filter_district:
            query['district'] = f'eq.{filter_district}'
        response = requests.get(
            f'{url}/rest/v1/market_prices', params=query,
            headers={'apikey': key, 'Authorization': f'Bearer {key}'}, timeout=12,
        )
        response.raise_for_status()
        return response.json()

    scopes = [(state, district, f'{district}, {state}' if district else state)]
    if district:
        scopes.append((state, '', state))
    if state and state != 'All States':
        scopes.append(('', '', 'India'))
    for filter_state, filter_district, label in scopes:
        rows = fetch(filter_state, filter_district)
        grouped = {}
        dates = {}
        for row in rows:
            name = _normalize(row.get('commodity'))
            try:
                price = float(row.get('modal_price'))
                date = str(row.get('arrival_date'))[:10]
                observed = datetime.strptime(date, '%Y-%m-%d').date()
            except (TypeError, ValueError):
                continue
            age_days = (datetime.now(timezone.utc).date() - observed).days
            if not name or price <= 0 or age_days < 0 or age_days > 3:
                continue
            if name not in dates:
                dates[name] = date
            if date == dates[name]:
                grouped.setdefault(name, []).append(price)
        prices = {name: sum(values) / len(values) for name, values in grouped.items()}
        if prices:
            return prices, dates, {name: label for name in prices}
    return {}, {}, {}


def _market_match(crop_name: str, prices: dict) -> str | None:
    candidates = (crop_name.lower(), *ALIASES.get(crop_name.lower(), ()))
    return next((candidate for candidate in candidates if candidate in prices), None)


def recommend(params: dict) -> dict:
    required = ('soilType', 'temperature', 'rainfall', 'season')
    missing = [key for key in required if params.get(key) is None]
    if missing:
        raise RuntimeError(f'Missing required recommendation inputs: {", ".join(missing)}.')
    soil_type = str(params['soilType']).strip()
    temperature = float(params['temperature'])
    rainfall = float(params['rainfall'])
    season_input = str(params['season']).strip()
    season = season_input.split(' ')[0].split('(')[0]
    state = params.get('state') or 'All States'
    district = params.get('district') or ''

    scores = []
    for crop in CROP_DB:
        if season not in crop['seasons']:
            continue
        soil_fit = 1.0 if soil_type in crop['soils'] else 0.0
        temp_fit = _range_fit(temperature, crop['temp_opt'], crop['temp_abs'])
        rain_fit = _range_fit(rainfall, crop['rain_opt'], crop['rain_abs'])
        # Season and soil are hard constraints. Climate compatibility tapers
        # between documented optimal and absolute bands rather than binary hits.
        if not soil_fit or temp_fit == 0 or rain_fit == 0:
            continue
        agro_score = 0.4 * soil_fit + 0.3 * temp_fit + 0.3 * rain_fit
        scores.append((crop, agro_score, soil_fit, temp_fit, rain_fit))
    scores.sort(key=lambda item: item[1], reverse=True)
    if not scores:
        raise RuntimeError(
            'No crops in the current catalogue fit all selected soil, season, temperature, and rainfall constraints. '
            'Try confirming your soil and rainfall estimate or ask your local KVK for a broader crop list.'
        )

    try:
        market_prices, price_dates, price_scopes = _current_market_prices(state, district)
        market_status = 'available' if market_prices else 'unavailable'
    except requests.RequestException:
        # Market service outages should not prevent an ecology-based result.
        market_prices, price_dates, price_scopes = {}, {}, {}
        market_status = 'temporarily_unavailable'

    recommendations = []
    for crop, score, soil_fit, temp_fit, rain_fit in scores[:5]:
        matched = _market_match(crop['name'], market_prices)
        price = market_prices.get(matched) if matched else None
        price_date = price_dates.get(matched) if matched else None
        market_scope = price_scopes.get(matched) if matched else None
        recommendations.append({
            'crop': crop['name'],
            'emoji': crop['emoji'],
            'matchScore': round(score, 2),
            'fitFactors': {
                'soil': round(soil_fit, 2),
                'temperature': round(temp_fit, 2),
                'seasonalRainfall': round(rain_fit, 2),
                'season': 1.0,
            },
            'suitableSoils': crop['soils'],
            'duration': crop['duration'],
            'waterRequirement': crop['water'],
            'reason': (
                f"Agro-ecological fit: {soil_type} soil, {season} season, "
                f"{temperature:.0f}°C current weather and {rainfall:.0f}mm seasonal rainfall estimate."
            ),
            'marketPrice': round(price, 2) if price is not None else None,
            'priceDate': price_date,
            'marketScope': market_scope,
        })

    observed_dates = [item['priceDate'] for item in recommendations if item['priceDate']]
    return {
        'recommendations': recommendations,
        'inputs': {
            'soilType': soil_type, 'temperature': temperature, 'rainfall': rainfall,
            'season': season, 'state': state, 'district': district or None,
        },
        'method': 'Explainable ecology screening; market prices are displayed separately and never change agronomic fit scores.',
        'ecologySource': 'Bundled screening ranges (not a direct FAO database import)',
        'referenceFramework': 'FAO ECOCROP crop-requirement framework',
        'ecologySourceUrl': 'https://ecocrop.apps.fao.org/ecocrop/srv/en/home',
        'marketDataSource': 'Supabase Agmarknet observations',
        'marketDataStatus': market_status,
        'lastObservedDate': max(observed_dates, default=None),
        'limitations': [
            'This is a screening aid, not a substitute for soil testing, irrigation assessment, variety selection, or local KVK/ICAR advice.',
            'The app rainfall input is a seasonal estimate; detailed local crop calendars and farm water availability are not yet modeled.',
        ],
    }
