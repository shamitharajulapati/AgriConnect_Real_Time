import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESOURCE_URL =
  'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';
const MAX_AGE_DAYS = 30;

function parseDate(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const value = raw.trim();
  const isoMatch = value.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  const slashMatch = value.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!isoMatch && !slashMatch) return null;
  const yearText = isoMatch ? isoMatch[1] : slashMatch![3];
  const monthText = isoMatch ? isoMatch[2] : slashMatch![2];
  const dayText = isoMatch ? isoMatch[3] : slashMatch![1];
  const day = Number(dayText);
  const month = Number(monthText);
  const year = Number(yearText);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;
  return `${yearText}-${monthText.padStart(2, '0')}-${dayText.padStart(2, '0')}`;
}

function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number'
    ? String(value).trim()
    : '';
}

function price(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'POST required' }, { status: 405 });
  }

  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret || request.headers.get('x-cron-secret') !== cronSecret) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const apiKey = Deno.env.get('AGMARKNET_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!apiKey || !supabaseUrl || !serviceKey) {
    console.error('Required function secrets are missing');
    return Response.json({ error: 'Server configuration is incomplete' }, { status: 500 });
  }

  const url = new URL(RESOURCE_URL);
  url.searchParams.set('api-key', apiKey);
  url.searchParams.set('format', 'json');
  url.searchParams.set('limit', '1000');
  url.searchParams.set('offset', '0');
  url.searchParams.set('sort[Arrival_Date]', 'desc');

  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(25000) });
    if (!response.ok) {
      console.error(`data.gov.in returned HTTP ${response.status}`);
      return Response.json({ error: `data.gov.in returned HTTP ${response.status}` }, { status: 502 });
    }

    const payload = await response.json();
    const sourceRows = Array.isArray(payload.records) ? payload.records : [];
    const rows = sourceRows.map((row: Record<string, unknown>) => {
      const arrivalDate = parseDate(row.Arrival_Date ?? row.arrival_date);
      const state = text(row.State ?? row.state);
      const market = text(row.Market ?? row.market);
      const commodity = text(row.Commodity ?? row.commodity);
      const variety = text(row.Variety ?? row.variety);
      const grade = text(row.Grade ?? row.grade);
      const minPrice = price(row.Min_Price ?? row.min_price);
      const maxPrice = price(row.Max_Price ?? row.max_price);
      const modalPrice = price(row.Modal_Price ?? row.modal_price);
      if (!arrivalDate || !state || !market || !commodity || !modalPrice) return null;

      const id = `${state}_${market}_${commodity}_${variety}_${grade}_${arrivalDate}`
        .replace(/[^a-zA-Z0-9_-]/g, '_');
      return {
        id,
        commodity,
        market,
        state,
        district: text(row.District ?? row.district),
        min_price: minPrice,
        max_price: maxPrice,
        modal_price: modalPrice,
        unit: 'quintal',
        arrival_date: arrivalDate,
        source: 'agmarknet',
      };
    }).filter((row): row is NonNullable<typeof row> => row !== null);

    const uniqueRows = [...new Map(rows.map((row) => [row.id, row])).values()];
    if (!uniqueRows.length) {
      return Response.json({ error: 'data.gov.in returned no usable price rows' }, { status: 502 });
    }

    const latestDate = uniqueRows.reduce(
      (latest, row) => row.arrival_date > latest ? row.arrival_date : latest,
      uniqueRows[0].arrival_date,
    );
    const ageDays = Math.floor((Date.now() - Date.parse(`${latestDate}T00:00:00Z`)) / 86400000);
    if (ageDays > MAX_AGE_DAYS) {
      console.error(`Latest source price is ${ageDays} days old (${latestDate}); refusing stale sync`);
      return Response.json({ error: 'Latest source data is more than 30 days old', latestDate }, { status: 502 });
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await supabase.from('market_prices').upsert(uniqueRows, { onConflict: 'id' });
    if (error) {
      console.error(`Supabase upsert failed: ${error.message}`);
      return Response.json({ error: 'Supabase upsert failed' }, { status: 500 });
    }

    console.log(`Saved ${uniqueRows.length} live rows; newest arrival date ${latestDate}`);
    return Response.json({ saved: uniqueRows.length, latestDate });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown sync error';
    console.error(`Market-price sync failed: ${message}`);
    return Response.json({ error: 'Market-price sync failed', detail: message }, { status: 502 });
  }
});
