from app import app


def test_health_reports_service_ready():
    response = app.test_client().get('/health')

    assert response.status_code == 200
    body = response.get_json()
    assert body['status'] == 'ok'
    assert body['service'] == 'agriconnect-ml'


def test_prediction_requires_authentication():
    response = app.test_client().post('/predict', json={'commodity': 'Tomato'})

    assert response.status_code == 401
    assert response.get_json()['error'] == 'Unauthorized'
