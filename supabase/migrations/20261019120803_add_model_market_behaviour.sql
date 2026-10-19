-- How each model's market behaves, from listings and their price history.
-- "Gone" = removed or sold: we can't tell a sale from a withdrawal.
-- Drops are measured against the first price we saw (initial_price).
create view public.model_market_behaviour
with (security_invoker = true) as
with base as (
  select
    l.motorcycle_id,
    l.status,
    l.price,
    l.initial_price,
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