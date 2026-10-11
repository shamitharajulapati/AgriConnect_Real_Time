// Keep backend route tests independent from live Supabase credentials/network.
jest.mock('../src/config/supabase', () => {
  const rows = [{
    id: 'test-market-price',
    commodity: 'Tomato',
    market: 'Test Market',
    state: 'Maharashtra',
    min_price: 1200,
    modal_price: 1500,
    max_price: 1800,
    arrival_date: '2026-10-01',
    source: 'test',
  }];

  const query = {
    select: jest.fn(() => query),
    order: jest.fn(() => query),
    limit: jest.fn(() => query),
    eq: jest.fn(() => query),
    upsert: jest.fn(async () => ({ error: null })),
    then: (resolve, reject) => Promise.resolve({ data: rows, error: null }).then(resolve, reject),
  };

  return { from: jest.fn(() => query) };
});
