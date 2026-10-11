from flask import Flask, request, jsonify
import os
import re
import requests

app = Flask(__name__)
SECRET = os.getenv('ML_SERVICE_SECRET')


@app.after_request
def add_browser_cors_headers(response):
    """Allow Flutter Web's authenticated cross-origin API calls safely."""
    origin = request.headers.get('Origin', '')
    host = origin.split('://', 1)[-1].split('/', 1)[0].split(':', 1)[0].lower()
    configured_origins = {
        item.strip().rstrip('/')
        for item in os.getenv('CORS_ALLOWED_ORIGINS', '').split(',')
        if item.strip()
    }
    is_local_dev = host in {'localhost', '127.0.0.1'}
    if is_local_dev or origin.rstrip('/') in configured_origins:
        response.headers['Access-Control-Allow-Origin'] = origin
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-Secret'
        response.headers['Access-Control-Max-Age'] = '600'
        response.headers.add('Vary', 'Origin')
    return response

def verify_secret():
    # Allow the backend to authenticate server-to-server with a secret kept
    # only in server configuration.
    if SECRET and request.headers.get('X-Secret') == SECRET:
        return True

    # Mobile requests use the signed-in user's Supabase session token. Validate
    # it with Supabase instead of shipping a reusable ML secret in the APK.
    authorization = request.headers.get('Authorization', '')
    supabase_url = os.getenv('SUPABASE_URL', '').rstrip('/')
    supabase_anon_key = os.getenv('SUPABASE_ANON_KEY', '')
    if not authorization.startswith('Bearer ') or not supabase_url or not supabase_anon_key:
        return False
    try:
        response = requests.get(
            f'{supabase_url}/auth/v1/user',
            headers={'apikey': supabase_anon_key, 'Authorization': authorization},
            timeout=5,
        )
        return response.status_code == 200
    except requests.RequestException:
        return False

@app.route('/health')
def health():
    auth_configured = bool(SECRET or (os.getenv('SUPABASE_URL') and os.getenv('SUPABASE_ANON_KEY')))
    market_sync_configured = bool(
        os.getenv('AGMARKNET_API_KEY')
        and os.getenv('SUPABASE_URL')
        and os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    )
    return jsonify({
        'status': 'ok',
        'service': 'agriconnect-ml',
        'version': '2.1.0',
        'auth_configured': auth_configured,
        'market_sync_configured': market_sync_configured,
    })


@app.route('/market/prices', methods=['POST'])
def market_prices():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    api_key = os.getenv('AGMARKNET_API_KEY', '')
    supabase_url = os.getenv('SUPABASE_URL', '').rstrip('/')
    service_role_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
    if not api_key or not supabase_url or not service_role_key:
        return jsonify({'error': 'Live market sync is not configured on the server.'}), 503

    try:
        limit = max(1, min(int(data.get('limit', 500)), 500))
    except (TypeError, ValueError):
        return jsonify({'error': 'limit must be an integer between 1 and 500'}), 400
    params = {'api-key': api_key, 'format': 'json', 'limit': limit}
    state = data.get('state')
    commodity = data.get('commodity')
    if state and state != 'All States':
        params['filters[state]'] = state
    if commodity and commodity != 'All':
        params['filters[commodity]'] = commodity
    try:
        response = requests.get(
            'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070',
            params=params,
            timeout=20,
        )
        response.raise_for_status()
        records = response.json().get('records', [])
        rows = []
        for record in records:
            raw_date = str(record.get('arrival_date', '')).strip()
            if '/' in raw_date:
                day, month, year = raw_date.split('/')
                arrival_date = f'{year}-{month.zfill(2)}-{day.zfill(2)}'
            else:
                arrival_date = raw_date[:10]
            try:
                min_price = float(record.get('min_price') or 0)
                max_price = float(record.get('max_price') or 0)
                modal_price = float(record.get('modal_price') or 0)
            except (TypeError, ValueError):
                continue
            commodity_name = str(record.get('commodity') or '').strip()
            market_name = str(record.get('market') or '').strip()
            state_name = str(record.get('state') or '').strip()
            if not arrival_date or not commodity_name or not market_name or not state_name or modal_price <= 0:
                continue
            row_id = re.sub(r'[^a-zA-Z0-9_-]', '_', f'{state_name}_{market_name}_{commodity_name}_{arrival_date}')
            rows.append({
                'id': row_id,
                'commodity': commodity_name,
                'market': market_name,
                'state': state_name,
                'district': record.get('district') or '',
                'min_price': min_price,
                'max_price': max_price,
                'modal_price': modal_price,
                'unit': 'quintal',
                'arrival_date': arrival_date,
                'source': 'agmarknet',
            })
        if not rows:
            return jsonify({'error': 'Agmarknet returned no valid market records.'}), 502

        saved = requests.post(
            f'{supabase_url}/rest/v1/market_prices?on_conflict=id',
            json=rows,
            headers={
                'apikey': service_role_key,
                'Authorization': f'Bearer {service_role_key}',
                'Content-Type': 'application/json',
                'Prefer': 'resolution=merge-duplicates,return=minimal',
            },
            timeout=20,
        )
        saved.raise_for_status()
        return jsonify({'records': len(rows), 'latestArrivalDate': max(r['arrival_date'] for r in rows)})
    except (requests.RequestException, ValueError):
        return jsonify({'error': 'Live market source or database write failed.'}), 502

@app.route('/predict', methods=['POST'])
def predict():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    commodity = data.get('commodity', 'Tomato')
    state = data.get('state', 'Karnataka')
    try:
        days = int(data.get('days', 7))
    except (TypeError, ValueError):
        return jsonify({'error': 'days must be an integer between 1 and 90'}), 400
    if not 1 <= days <= 90:
        return jsonify({'error': 'days must be between 1 and 90'}), 400

    from api.price_prediction import predict as ml_predict
    return jsonify(ml_predict({'commodity': commodity, 'state': state, 'days': days}))

@app.route('/crop-reco', methods=['POST'])
def crop_reco():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    from api.crop_recommendation import recommend
    return jsonify(recommend(data))

@app.route('/demand', methods=['POST'])
def demand():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    from api.demand_forecast import forecast_demand
    return jsonify(forecast_demand(data.get('commodity'), data.get('state')))

@app.route('/profit', methods=['POST'])
def profit():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.json or {}
    from api.profit_advisor import advise
    return jsonify(advise(data))

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
