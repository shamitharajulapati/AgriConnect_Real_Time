import pytest

from api import crop_recommendation as crop_reco


def test_agronomic_screening_returns_fit_without_market_service(monkeypatch):
    monkeypatch.setattr(crop_reco, '_current_market_prices', lambda *_args: ({}, {}, {}))

    result = crop_reco.recommend({
        'soilType': 'Clay',
        'season': 'Kharif (Jun-Sep)',
        'temperature': 25,
        'rainfall': 1400,
        'state': 'West Bengal',
        'district': 'Nadia',
    })

    rice = next(item for item in result['recommendations'] if item['crop'] == 'Rice')
    assert rice['matchScore'] == 1.0
    assert rice['marketPrice'] is None
    assert result['marketDataStatus'] == 'unavailable'
    assert result['inputs']['district'] == 'Nadia'


def test_market_price_does_not_change_agronomic_match_score(monkeypatch):
    params = {
        'soilType': 'Clay', 'season': 'Kharif', 'temperature': 25,
        'rainfall': 1400, 'state': 'West Bengal',
    }
    monkeypatch.setattr(crop_reco, '_current_market_prices', lambda *_args: ({}, {}, {}))
    without_market = crop_reco.recommend(params)

    monkeypatch.setattr(
        crop_reco, '_current_market_prices',
        lambda *_args: ({'rice': 2500.0}, {'rice': '2026-11-21'}, {'rice': 'West Bengal'}),
    )
    with_market = crop_reco.recommend(params)

    assert with_market['recommendations'][0]['matchScore'] == without_market['recommendations'][0]['matchScore']
    assert with_market['recommendations'][0]['marketPrice'] == 2500.0


def test_crop_outside_absolute_temperature_band_is_not_recommended(monkeypatch):
    monkeypatch.setattr(crop_reco, '_current_market_prices', lambda *_args: ({}, {}, {}))

    with pytest.raises(RuntimeError, match='No crops in the current catalogue fit'):
        crop_reco.recommend({
            'soilType': 'Clay', 'season': 'Kharif', 'temperature': 45,
            'rainfall': 1400, 'state': 'West Bengal',
        })
