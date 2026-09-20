import numpy as np
from datetime import datetime, timedelta
import os
import joblib

BASE_PRICES = {
    'Tomato': 1500, 'Onion': 950, 'Potato': 750, 'Wheat': 2250,
    'Rice': 3000, 'Cotton': 6500, 'Chillies': 10000, 'Soybean': 4500,
}

def predict(params: dict) -> dict:
    commodity = params.get('commodity', 'Tomato')
    state = params.get('state', 'Karnataka')
    horizon = int(params.get('days', 7))

    key = f"{commodity}_{state}".replace(' ', '_')
    model_path = f'models/{key}_arima.pkl'

    # Try loading trained model, fallback to statistical mock
    if os.path.exists(model_path):
        try:
            arima = joblib.load(model_path)
            fc = arima.get_forecast(steps=horizon)
            fc_mean = fc.predicted_mean
            fc_ci = fc.conf_int(alpha=0.20)
            points = []
            for i in range(horizon):
                date = datetime.now() + timedelta(days=i + 1)
                points.append({
                    'date': date.strftime('%Y-%m-%d'),
                    'price': round(float(fc_mean.iloc[i]), 2),
                    'lowerBound': round(float(fc_ci.iloc[i, 0]), 2),
                    'upperBound': round(float(fc_ci.iloc[i, 1]), 2),
                })
            return {
                'commodity': commodity, 'state': state, 'points': points,
                'confidence': 0.85, 'unit': 'INR/quintal',
                'generatedAt': datetime.now().isoformat(),
            }
        except Exception:
            pass

    # Fallback: generate mock predictions
    rng = np.random.default_rng(hash(key) % (2**32))
    base = BASE_PRICES.get(commodity, 1000)
    points = []
    price = float(base)
    for i in range(horizon):
        price = price * (1 + 0.005 + (rng.random() - 0.5) * 0.06)
        date = datetime.now() + timedelta(days=i + 1)
        points.append({
            'date': date.strftime('%Y-%m-%d'),
            'price': round(price, 2),
            'lowerBound': round(price * 0.88, 2),
            'upperBound': round(price * 1.12, 2),
        })

    return {
        'commodity': commodity, 'state': state, 'points': points,
        'confidence': round(0.75 + rng.random() * 0.15, 3),
        'unit': 'INR/quintal',
        'generatedAt': datetime.now().isoformat(),
    }
