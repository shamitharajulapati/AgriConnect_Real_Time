-- Enable Supabase Realtime notifications for new or updated market rows.
-- Safe to run more than once in Supabase SQL Editor.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'market_prices'
  ) then
    alter publication supabase_realtime add table public.market_prices;
  end if;
end
$$;
