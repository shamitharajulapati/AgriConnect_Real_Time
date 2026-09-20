-- AgriConnect RLS policies.
-- Run this once in Supabase Dashboard → SQL Editor → New query.
-- Safe to re-run: every policy is dropped before being recreated.
--
-- Why: market_prices currently has RLS blocking ALL reads, including from the
-- anon key the app ships with — meaning the app can never see real prices
-- until a policy explicitly allows it. This script:
--   1. Makes market data (market_prices, price_predictions) publicly
--      readable — it's public government mandi data, no reason to gate it
--      behind login. Writes stay restricted to the service_role key (used
--      only by the sync scripts), except price_predictions which the app
--      itself caches into as a signed-in user.
--   2. Scopes farmer-private data (alerts, chat_rooms, messages, farmers) so
--      each signed-in user can only see and modify their own rows.

-- ── market_prices — public read, service-role-only write ───────────────────
alter table market_prices enable row level security;

drop policy if exists "Public read market_prices" on market_prices;
create policy "Public read market_prices" on market_prices
  for select using (true);

-- ── price_predictions — public read; signed-in users cache their own forecasts ─
alter table price_predictions enable row level security;

drop policy if exists "Public read price_predictions" on price_predictions;
create policy "Public read price_predictions" on price_predictions
  for select using (true);

drop policy if exists "Authenticated insert price_predictions" on price_predictions;
create policy "Authenticated insert price_predictions" on price_predictions
  for insert with check (auth.role() = 'authenticated');

drop policy if exists "Authenticated update price_predictions" on price_predictions;
create policy "Authenticated update price_predictions" on price_predictions
  for update using (auth.role() = 'authenticated');

-- ── alerts — farmer sees and manages only their own alerts ─────────────────
alter table alerts enable row level security;

drop policy if exists "Farmers select own alerts" on alerts;
create policy "Farmers select own alerts" on alerts
  for select using (auth.uid() = farmer_id);

drop policy if exists "Farmers insert own alerts" on alerts;
create policy "Farmers insert own alerts" on alerts
  for insert with check (auth.uid() = farmer_id);

drop policy if exists "Farmers update own alerts" on alerts;
create policy "Farmers update own alerts" on alerts
  for update using (auth.uid() = farmer_id);

drop policy if exists "Farmers delete own alerts" on alerts;
create policy "Farmers delete own alerts" on alerts
  for delete using (auth.uid() = farmer_id);

-- ── farmers — a user can only see and edit their own profile ───────────────
alter table farmers enable row level security;

drop policy if exists "Farmers select own profile" on farmers;
create policy "Farmers select own profile" on farmers
  for select using (auth.uid() = id);

drop policy if exists "Farmers insert own profile" on farmers;
create policy "Farmers insert own profile" on farmers
  for insert with check (auth.uid() = id);

drop policy if exists "Farmers update own profile" on farmers;
create policy "Farmers update own profile" on farmers
  for update using (auth.uid() = id);

-- ── chat_rooms — only the two participants can see or touch a room ─────────
alter table chat_rooms enable row level security;

drop policy if exists "Participants select chat_rooms" on chat_rooms;
create policy "Participants select chat_rooms" on chat_rooms
  for select using (auth.uid() = farmer_id or auth.uid() = buyer_id);

drop policy if exists "Participants insert chat_rooms" on chat_rooms;
create policy "Participants insert chat_rooms" on chat_rooms
  for insert with check (auth.uid() = farmer_id or auth.uid() = buyer_id);

drop policy if exists "Participants update chat_rooms" on chat_rooms;
create policy "Participants update chat_rooms" on chat_rooms
  for update using (auth.uid() = farmer_id or auth.uid() = buyer_id);

-- ── messages — only participants in the parent room can read/send ──────────
alter table messages enable row level security;

drop policy if exists "Room participants select messages" on messages;
create policy "Room participants select messages" on messages
  for select using (
    exists (
      select 1 from chat_rooms r
      where r.id = messages.room_id
        and (r.farmer_id = auth.uid() or r.buyer_id = auth.uid())
    )
  );

drop policy if exists "Room participants insert messages" on messages;
create policy "Room participants insert messages" on messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from chat_rooms r
      where r.id = messages.room_id
        and (r.farmer_id = auth.uid() or r.buyer_id = auth.uid())
    )
  );

drop policy if exists "Room participants update messages" on messages;
create policy "Room participants update messages" on messages
  for update using (
    exists (
      select 1 from chat_rooms r
      where r.id = messages.room_id
        and (r.farmer_id = auth.uid() or r.buyer_id = auth.uid())
    )
  );
