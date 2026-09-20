"""
Trains ARIMA(p,d,q) price-forecasting models per (commodity, state), following
the methodology in AgriConnect_EPICS_Review1_Updated_1.pptx (slide 7):

  1. Stationarity check       -> Augmented Dickey-Fuller test
  2. Differencing             -> order d chosen until ADF rejects the unit-root H0
  3. Order selection (p, q)   -> small grid search scored by AIC (ACF/PACF-guided range)
  4. Estimation                -> Maximum Likelihood (statsmodels ARIMA)
  5. Residual diagnostics      -> Ljung-Box test
  6. Evaluation                -> MAPE / RMSE on a held-out window vs. a naive
                                   persistence baseline

Usage: python train_arima.py
Writes one models/{Commodity}_{State}_arima.pkl per pair, loadable by
api/price_prediction.py via joblib.
"""
import os
import warnings
import joblib
import numpy as np
import pandas as pd
from statsmodels.tsa.stattools import adfuller
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.stats.diagnostic import acorr_ljungbox

from historical_data import ANCHOR_PRICES, generate_history

warnings.filterwarnings('ignore')

MODELS_DIR = os.path.join(os.path.dirname(__file__), '..', 'models')
TEST_HORIZON = 14          # held-out days for backtesting
MAX_P, MAX_Q = 3, 3        # search range for AR / MA order


def find_d(series: pd.Series, max_d: int = 2, alpha: float = 0.05) -> int:
    """Augmented Dickey-Fuller test, differencing until stationary (or max_d reached)."""
    s = series.copy()
    for d in range(max_d + 1):
        pvalue = adfuller(s.dropna(), autolag='AIC')[1]
        if pvalue < alpha:
            return d
        s = s.diff()
    return max_d


def select_order(train: pd.Series, d: int) -> tuple:
    """Grid search (p, q) at the chosen d, scored by AIC — a practical stand-in
    for manual ACF/PACF correlogram inspection."""
    best_aic, best_order = np.inf, (1, d, 1)
    for p in range(0, MAX_P + 1):
        for q in range(0, MAX_Q + 1):
            if p == 0 and q == 0:
                continue
            try:
                fit = ARIMA(train, order=(p, d, q)).fit()
                if fit.aic < best_aic:
                    best_aic, best_order = fit.aic, (p, d, q)
            except Exception:
                continue
    return best_order


def evaluate(train: pd.Series, test: pd.Series, order: tuple) -> dict:
    """Backtest: refit on train, forecast len(test) steps, compare MAPE/RMSE
    against a naive persistence baseline (tomorrow = today's last price)."""
    fit = ARIMA(train, order=order).fit()
    forecast = fit.get_forecast(steps=len(test)).predicted_mean.values
    actual = test.values

    mape = float(np.mean(np.abs((actual - forecast) / actual)) * 100)
    rmse = float(np.sqrt(np.mean((actual - forecast) ** 2)))

    naive = np.full(len(test), train.values[-1])
    naive_mape = float(np.mean(np.abs((actual - naive) / actual)) * 100)

    lb = acorr_ljungbox(fit.resid, lags=[10], return_df=True)
    ljung_box_p = float(lb['lb_pvalue'].iloc[0])

    return {'mape': mape, 'rmse': rmse, 'naive_mape': naive_mape, 'ljung_box_p': ljung_box_p}


def train_one(commodity: str, state: str, anchor_price: float) -> dict:
    series = generate_history(commodity, state, anchor_price)
    train, test = series.iloc[:-TEST_HORIZON], series.iloc[-TEST_HORIZON:]

    d = find_d(train)
    order = select_order(train, d)
    metrics = evaluate(train, test, order)

    # Final model: fit on the full series so forecasts start from "today"
    final_fit = ARIMA(series, order=order).fit()

    key = f"{commodity}_{state}".replace(' ', '_')
    os.makedirs(MODELS_DIR, exist_ok=True)
    joblib.dump(final_fit, os.path.join(MODELS_DIR, f'{key}_arima.pkl'))

    return {'commodity': commodity, 'state': state, 'order': order, **metrics}


def main():
    print(f"Training ARIMA models for {len(ANCHOR_PRICES)} (commodity, state) pairs...\n")
    report = []
    for (commodity, state), anchor_price in ANCHOR_PRICES.items():
        try:
            result = train_one(commodity, state, anchor_price)
            report.append(result)
            print(f"[OK] {commodity:10} / {state:16} order={result['order']}  "
                  f"MAPE={result['mape']:.1f}% (naive {result['naive_mape']:.1f}%)  "
                  f"RMSE={result['rmse']:.1f}  Ljung-Box p={result['ljung_box_p']:.3f}")
        except Exception as e:
            print(f"[ERR] {commodity} / {state}: {e}")

    if report:
        avg_mape = np.mean([r['mape'] for r in report])
        avg_naive = np.mean([r['naive_mape'] for r in report])
        print(f"\nDone. {len(report)} models saved to {os.path.abspath(MODELS_DIR)}")
        print(f"Average MAPE: {avg_mape:.1f}% vs naive-persistence baseline {avg_naive:.1f}%")


if __name__ == '__main__':
    main()
