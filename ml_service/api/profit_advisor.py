from datetime import datetime
from api.price_prediction import predict as predict_price, BASE_PRICES


def advise(params: dict) -> dict:
    commodity = params.get('commodity', 'Tomato')
    state = params.get('state', 'Karnataka')

    current_price = float(BASE_PRICES.get(commodity, 1000))

    forecast = predict_price({'commodity': commodity, 'state': state, 'days': 14})
    points = forecast['points']
    confidence = forecast.get('confidence', 0.75)

    price_7d = points[6]['price'] if len(points) > 6 else points[-1]['price']
    price_14d = points[13]['price'] if len(points) > 13 else points[-1]['price']

    roi_7d = (price_7d - current_price) / current_price * 100
    roi_14d = (price_14d - current_price) / current_price * 100

    factors = [
        f"7-day price outlook {'+' if roi_7d >= 0 else ''}{roi_7d:.1f}%",
        f"14-day price outlook {'+' if roi_14d >= 0 else ''}{roi_14d:.1f}%",
    ]

    if roi_14d > roi_7d + 2 and roi_14d > 3:
        decision = 'hold14'
        projected_price = price_14d
        roi = roi_14d
        reason = f'{commodity} prices are projected to keep rising through day 14. Holding longer should maximize returns.'
        factors.append('Upward trend strengthens beyond 7 days')
    elif roi_7d > 3:
        decision = 'hold7'
        projected_price = price_7d
        roi = roi_7d
        reason = f'{commodity} prices are trending upward this week. Holding 7 days should improve returns.'
        factors.append('Short-term upward momentum')
    else:
        decision = 'sellNow'
        projected_price = price_7d
        roi = roi_7d
        reason = f'{commodity} prices are flat or falling. Selling now avoids potential losses from holding.'
        factors.append('Limited upside, downside risk present')

    factors.append(f'Forecast confidence {round(confidence * 100)}%')

    return {
        'commodity': commodity,
        'state': state,
        'decision': decision,
        'currentPrice': round(current_price, 2),
        'projectedPrice': round(projected_price, 2),
        'roi': round(roi, 2),
        'confidence': round(confidence * 100),
        'reason': reason,
        'factors': factors,
        'generatedAt': datetime.now().isoformat(),
    }
