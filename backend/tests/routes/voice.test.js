const request = require('supertest');
const app = require('../../server');

const TOKEN = 'mock_valid_token_123456';

describe('POST /api/voice/query', () => {
  it('returns 401 without auth', async () => {
    const res = await request(app).post('/api/voice/query').send({ query: 'tomato price', language: 'en' });
    expect(res.status).toBe(401);
  });

  it('understands price query in English', async () => {
    const res = await request(app)
      .post('/api/voice/query')
      .set('Authorization', `Bearer ${TOKEN}`)
      .send({ query: 'What is the tomato price today?', language: 'en' });
    expect(res.status).toBe(200);
    expect(res.body.intent.action).toBe('GET_PRICE');
    expect(res.body.answer).toContain('1500');
  });

  it('understands crop recommendation query', async () => {
    const res = await request(app)
      .post('/api/voice/query')
      .set('Authorization', `Bearer ${TOKEN}`)
      .send({ query: 'Which crop should I grow?', language: 'en' });
    expect(res.status).toBe(200);
    expect(res.body.intent.action).toBe('CROP_RECOMMENDATION');
  });
});
