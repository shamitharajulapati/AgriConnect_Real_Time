import os
from collections import defaultdict
from datetime import date, datetime, timedelta

import requests


def forecast_demand(commodity: str, state: str = None) -> dict:
    """Estimate market activity from recent Agmarknet observations.

    Agmarknet publishes prices, not buyer orders. This is therefore a market
    activity proxy and must not be represented as measured buyer demand.
    """
    url = os.getenv('SUPABASE_URL', '').rstrip('/')
    key = os.getenv('SUPABASE_ANON_KEY', '')
    if not url or not key:
        raise RuntimeError('Supabase market data is not configured for demand estimates.')

    cutoff = (date.today() - timedelta(days=30)).isoformat()
    params = {
        'select': 'commodity,state,market,arrival_date,modal_price',
        'commodity': f'eq.{commodity}',
        'arrival_date': f'gte.{cutoff}',
        # Preserve the latest records when the result set hits its row limit.
        'order': 'arrival_date.desc',
        'limit': '1000',
    }
    if state and state != 'All States':
        params['state'] = f'eq.{state}'

    response = requests.get(
        f'{url}/rest/v1/market_prices',
        params=params,
        headers={'apikey': key, 'Authorization': f'Bearer {key}'},
        timeout=12,
    )
    response.raise_for_status()
    rows = response.json()
    if not rows and state and state != 'All States':
        params.pop('state', None)
        response = requests.get(
            f'{url}/rest/v1/market_prices',
            params=params,
            headers={'apikey': key, 'Authorization': f'Bearer {key}'},
            timeout=12,
        )
        response.raise_for_status()
        rows = response.json()

    if not rows:
        raise RuntimeError(f'No recent Agmarknet records are available for {commodity}.')

    parsed_rows = []
    for row in rows:
        try:
            observed = datetime.strptime(row['arrival_date'][:10], '%Y-%m-%d').date()
            price = float(row['modal_price'])
        except (KeyError, TypeError, ValueError):
            continue
        market = str(row.get('market') or '').strip()
        region = str(row.get('state') or '').strip()
        if market and region and price > 0:
            parsed_rows.append((observed, market, region, price))
    if not parsed_rows:
        raise RuntimeError(f'No valid recent Agmarknet records are available for {commodity}.')

    latest_day = max(row[0] for row in parsed_rows)
    markets_by_day = defaultdict(set)
    prices_by_day = defaultdict(list)
    markets_by_region = defaultdict(set)
    for observed, market, region, price in parsed_rows:
        markets_by_day[observed].add(market)
        prices_by_day[observed].append(price)
        if observed == latest_day:
            markets_by_region[region].add(market)

    if not markets_by_day:
        raise RuntimeError(f'No valid recent Agmarknet records are available for {commodity}.')
    age_days = (date.today() - latest_day).days
    if age_days > 7:
        raise RuntimeError(f'Latest Agmarknet record for {commodity} is {age_days} days old.')

    days = sorted(prices_by_day)
    latest_price = sum(prices_by_day[latest_day]) / len(prices_by_day[latest_day])
    earlier = [prices_by_day[day] for day in days if day < latest_day][-7:]
    earlier_values = [price for prices in earlier for price in prices]
    previous_price = sum(earlier_values) / len(earlier_values) if earlier_values else latest_price
    change = (latest_price - previous_price) / previous_price if previous_price else 0.0
    trend = 'RISING' if change > 0.02 else 'FALLING' if change < -0.02 else 'STABLE'

    latest_market_count = len(markets_by_day[latest_day])
    maximum_market_count = max(len(markets) for markets in markets_by_day.values())
    activity_score = min(1.0, latest_market_count / max(1, maximum_market_count))
    price_signal = min(1.0, max(0.0, 0.5 + change * 2))
    index = round(0.65 * activity_score + 0.35 * price_signal, 3)
    level = 'HIGH' if index >= 0.7 else 'MEDIUM' if index >= 0.4 else 'LOW'

    regional_max = max((len(markets) for markets in markets_by_region.values()), default=1)
    regions = [
        {'region': region, 'demand': round(len(markets) / regional_max, 3)}
        for region, markets in sorted(markets_by_region.items(), key=lambda item: len(item[1]), reverse=True)[:5]
    ]
    weekly_demand = [
        round(max(0.0, min(100.0, index * 100 * (1 + (change * day / 7)))), 1)
        for day in range(1, 8)
    ]

    return {
        'commodity': commodity,
        'state': state or 'All States',
        'demandLevel': level,
        'demandIndex': index,
        'trend': trend,
        'peakExpectedDays': 7 if trend == 'RISING' else 14 if trend == 'STABLE' else 21,
        'weeklyDemand': weekly_demand,
        'regions': regions,
        'dataSource': 'Agmarknet market activity proxy',
        'lastObservedDate': latest_day.isoformat(),
        'generatedAt': datetime.now().isoformat(),
    }
