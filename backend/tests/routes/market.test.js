const request = require('supertest');
const app = require('../../server');

const MOCK_TOKEN = 'mock_valid_token_123456';

describe('GET /api/market/prices/:state', () => {
  it('returns 401 without auth header', async () => {
    const res = await request(app).get('/api/market/prices/Maharashtra');
    expect(res.status).toBe(401);
  });

  it('returns price list for valid state', async () => {
    const res = await request(app)
      .get('/api/market/prices/Maharashtra')
      .set('Authorization', `Bearer ${MOCK_TOKEN}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data[0]).toHaveProperty('modal_price');
    expect(res.body.state).toBe('Maharashtra');
  });

  it('filters by commodity', async () => {
    const res = await request(app)
      .get('/api/market/prices/Maharashtra?commodity=Tomato')
      .set('Authorization', `Bearer ${MOCK_TOKEN}`);
    expect(res.status).toBe(200);
    if (res.body.data.length > 0) {
      expect(res.body.data[0].commodity).toBe('Tomato');
    }
  });
});

describe('GET /health', () => {
  it('returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
