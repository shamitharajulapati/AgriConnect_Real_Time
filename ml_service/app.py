from flask import Flask, request, jsonify
import os
import re
import requests
from datetime import datetime

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
        if response.status_code != 200:
            app.logger.warning('Supabase rejected ML bearer authentication (HTTP %s)', response.status_code)
            return False
        return True
    except requests.RequestException as error:
        app.logger.warning('Could not validate ML bearer authentication (%s)', type(error).__name__)
        return False


def mobile_auth_configured():
    return bool(os.getenv('SUPABASE_URL') and os.getenv('SUPABASE_ANON_KEY'))

@app.route('/health')
def health():
    auth_configured = bool(SECRET or mobile_auth_configured())
    market_sync_configured = bool(
        os.getenv('AGMARKNET_API_KEY')
        and os.getenv('SUPABASE_URL')
        and os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    )
    return jsonify({
        'status': 'ok',
        'service': 'agriconnect-ml',
        'version': '2.2.0',
        'auth_configured': auth_configured,
        'mobile_auth_configured': mobile_auth_configured(),
        'server_auth_configured': bool(SECRET),
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

        latest_arrival = max(row['arrival_date'] for row in rows)
        try:
            latest_day = datetime.strptime(latest_arrival, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Agmarknet returned an invalid observation date.'}), 502
        if (datetime.now().date() - latest_day).days > 3:
            return jsonify({'error': 'Agmarknet has not published a recent observation for this filter.'}), 502

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
        return jsonify({'records': len(rows), 'latestArrivalDate': latest_arrival})
    except (requests.RequestException, ValueError):
        return jsonify({'error': 'Live market source or database write failed.'}), 502


@app.route('/market/sync', methods=['POST'])
def sync_market_prices():
    """Fetch daily Agmarknet rows from the hosted service and upsert them."""
    sync_secret = os.getenv('MARKET_SYNC_SECRET', '')
    if not sync_secret or request.headers.get('X-Secret') != sync_secret:
        return jsonify({'error': 'Unauthorized'}), 401

    api_key = os.getenv('AGMARKNET_API_KEY', '')
    supabase_url = os.getenv('SUPABASE_URL', '').rstrip('/')
    service_role_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
    if not api_key or not supabase_url or not service_role_key:
        return jsonify({'error': 'Market sync is not configured on the hosted service.'}), 503

    states = [
        'Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh', 'Telangana',
        'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan', 'Gujarat',
        'Kerala', 'West Bengal', 'Bihar',
    ]
    resource_url = 'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24'
    saved = 0
    failures = []
    newest_date = None

    for state in states:
        try:
            response = requests.get(resource_url, params={
                'api-key': api_key,
                'format': 'json',
                'limit': 1000,
                'offset': 0,
                'sort[Arrival_Date]': 'desc',
                'filters[State]': state,
            }, timeout=30)
            response.raise_for_status()
            payload = response.json()
            records = payload.get('records', []) if isinstance(payload, dict) else []
            if not isinstance(records, list):
                records = []
            rows_by_id = {}
            for record in records:
                raw_date = str(record.get('Arrival_Date') or record.get('arrival_date') or '').strip()
                try:
                    if '/' in raw_date:
                        arrival_date = datetime.strptime(raw_date, '%d/%m/%Y').date().isoformat()
                    else:
                        arrival_date = datetime.strptime(raw_date[:10], '%Y-%m-%d').date().isoformat()
                    minimum = float(record.get('Min_Price') or record.get('min_price') or 0)
                    maximum = float(record.get('Max_Price') or record.get('max_price') or 0)
                    modal = float(record.get('Modal_Price') or record.get('modal_price') or 0)
                except (TypeError, ValueError):
                    continue

                row_state = str(record.get('State') or record.get('state') or state).strip()
                market = str(record.get('Market') or record.get('market') or '').strip()
                commodity = str(record.get('Commodity') or record.get('commodity') or '').strip()
                variety = str(record.get('Variety') or record.get('variety') or '').strip()
                grade = str(record.get('Grade') or record.get('grade') or '').strip()
                if not arrival_date or not market or not commodity or modal <= 0:
                    continue

                row_id = re.sub(
                    r'[^a-zA-Z0-9_-]', '_',
                    f'{row_state}_{market}_{commodity}_{variety}_{grade}_{arrival_date}',
                )
                rows_by_id[row_id] = {
                    'id': row_id,
                    'commodity': commodity,
                    'market': market,
                    'state': row_state,
                    'district': str(record.get('District') or record.get('district') or '').strip(),
                    'min_price': minimum,
                    'max_price': maximum,
                    'modal_price': modal,
                    'unit': 'quintal',
                    'arrival_date': arrival_date,
                    'source': 'agmarknet',
                }
                newest_date = max(newest_date or arrival_date, arrival_date)

            rows = list(rows_by_id.values())
            for offset in range(0, len(rows), 200):
                result = requests.post(
                    f'{supabase_url}/rest/v1/market_prices?on_conflict=id',
                    json=rows[offset:offset + 200],
                    headers={
                        'apikey': service_role_key,
                        'Authorization': f'Bearer {service_role_key}',
                        'Content-Type': 'application/json',
                        'Prefer': 'resolution=merge-duplicates,return=minimal',
                    },
                    timeout=30,
                )
                result.raise_for_status()
            saved += len(rows)
            app.logger.info('Market sync: %s saved %s rows', state, len(rows))
        except (requests.RequestException, ValueError) as error:
            # The provider API key is in the request URL; never log exception
            # text or a traceback that could include that URL.
            app.logger.error('Market sync failed for %s (%s)', state, type(error).__name__)
            failures.append(state)

    if failures or not saved:
        return jsonify({
            'error': 'Market sync did not complete for all states.',
            'saved': saved,
            'failedStates': failures,
            'latestArrivalDate': newest_date,
        }), 502

    return jsonify({'saved': saved, 'states': len(states), 'latestArrivalDate': newest_date})

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
    try:
        return jsonify(ml_predict({'commodity': commodity, 'state': state, 'days': days}))
    except RuntimeError as error:
        return jsonify({'error': str(error)}), 503

@app.route('/crop-reco', methods=['POST'])
def crop_reco():
    if not verify_secret():
        if not mobile_auth_configured():
            return jsonify({
                'error': 'Mobile sign-in validation is not configured on the ML service. Configure SUPABASE_URL and SUPABASE_ANON_KEY.',
            }), 503
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    from api.crop_recommendation import recommend
    try:
        return jsonify(recommend(data))
    except RuntimeError as error:
        return jsonify({'error': str(error)}), 503
    except requests.RequestException:
        return jsonify({'error': 'Could not load recent market prices for crop recommendations.'}), 502

@app.route('/demand', methods=['POST'])
def demand():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json(silent=True) or {}
    from api.demand_forecast import forecast_demand
    try:
        return jsonify(forecast_demand(data.get('commodity'), data.get('state')))
    except RuntimeError as error:
        return jsonify({'error': str(error)}), 503

@app.route('/profit', methods=['POST'])
def profit():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.json or {}
    from api.profit_advisor import advise
    try:
        return jsonify(advise(data))
    except RuntimeError as error:
        return jsonify({'error': str(error)}), 503

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
