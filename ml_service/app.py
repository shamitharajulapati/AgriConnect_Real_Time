from flask import Flask, request, jsonify
import os

app = Flask(__name__)
SECRET = os.getenv('ML_SERVICE_SECRET', 'dev_secret_key')

def verify_secret():
    return request.headers.get('X-Secret') == SECRET

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'service': 'agriconnect-ml', 'version': '2.0.0'})

@app.route('/predict', methods=['POST'])
def predict():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.json
    commodity = data.get('commodity', 'Tomato')
    state = data.get('state', 'Karnataka')
    days = int(data.get('days', 7))

    from api.price_prediction import predict as ml_predict
    return jsonify(ml_predict({'commodity': commodity, 'state': state, 'days': days}))

@app.route('/crop-reco', methods=['POST'])
def crop_reco():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.json
    from api.crop_recommendation import recommend
    return jsonify(recommend(data))

@app.route('/demand', methods=['POST'])
def demand():
    if not verify_secret():
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.json
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
