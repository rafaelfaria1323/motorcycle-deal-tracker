-- The highest earlier price the site has reported for a listing. Standvirtual
-- shows a "priceDrop" with the lowest price in the 30 days before its last
-- cut; the note disappears after a while, so the value is kept. It can
-- predate our tracking, so it lives apart from listing_price_history (our
-- own observations) and never creates alerts. Null until the site reports
-- a cut.
alter table public.listings add column price_before_drop numeric(10, 2);

-- Called by the collector after every import with the cuts the site shows:
-- p_prices is {"<source_listing_id>": <price>, ...}. Keeps the highest value
-- seen; returns how many listings changed.
create function public.apply_prices_before_drop(p_source text, p_prices jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set price_before_drop = v.price
  from (
    select key as sid, value::numeric as price
    from jsonb_each_text(p_prices)
    where value is not null
  ) v
  where l.source = p_source
    and l.source_listing_id = v.sid
    and (l.price_before_drop is null or v.price > l.price_before_drop);

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_prices_before_drop(text, jsonb)
  from public, anon, authenticated;

-- Drops are now measured against the higher of the first price we saw and
-- the price the site reports before its last cut, so cuts made before we
-- started tracking count too.
create or replace view public.model_market_behaviour
with (security_invoker = true) as
with base as (
  select
    l.motorcycle_id,
    l.status,
    l.price,
    greatest(l.initial_price, l.price_before_drop) as initial_price,
    coalesce(l.published_at, l.first_seen_at) as listed_at,
    l.last_seen_at
  from public.listings l
  where l.motorcycle_id is not null
    and l.duplicate_of is null
)
select
  motorcycle_id,
  count(*) filter (where status in ('active', 'price_changed'))  as live_count,
  count(*) filter (where status in ('removed', 'sold'))          as gone_count,
  round((percentile_cont(0.5) within group (
      order by extract(epoch from last_seen_at - listed_at) / 86400)
    filter (where status in ('removed', 'sold')))::numeric, 0)   as median_days_to_gone,
  round((percentile_cont(0.5) within group (
      order by extract(epoch from now() - listed_at) / 86400)
    filter (where status in ('active', 'price_changed')))::numeric, 0)
                                                                 as median_days_listed_live,
  count(*) filter (where initial_price is not null)              as priced_count,
  count(*) filter (where initial_price is not null
                     and price < initial_price)                  as dropped_count,
  round((percentile_cont(0.5) within group (
      order by (initial_price - price) / initial_price * 100)
    filter (where initial_price is not null
              and price < initial_price))::numeric, 1)           as median_drop_pct
from base
group by motorcycle_id;
