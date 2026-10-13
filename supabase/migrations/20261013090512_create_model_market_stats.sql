-- Market reference price per catalog model, from live listings only.
-- security_invoker makes the view obey the caller's RLS on listings.
create view public.model_market_stats
with (security_invoker = true) as
select
  motorcycle_id,
  count(*)                                                    as listing_count,
  round(avg(price), 2)                                        as avg_price,
  round((percentile_cont(0.5) within group (order by price))::numeric, 2)
                                                              as median_price,
  min(price)                                                  as min_price,
  max(price)                                                  as max_price
from public.listings
where motorcycle_id is not null
  and price is not null
  and status in ('active', 'price_changed')
group by motorcycle_id;