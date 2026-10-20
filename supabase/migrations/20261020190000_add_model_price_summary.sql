-- Model comparison (10.2): the spread of each model's live asking prices,
-- with the typical year and mileage behind them. Live, non-duplicate
-- listings with a price, as in model_market_behaviour and the fair price.
create view public.model_price_summary
with (security_invoker = true) as
select
  l.motorcycle_id,
  count(*)                                                   as priced_live_count,
  min(l.price)                                               as min_price,
  round((percentile_cont(0.25) within group (order by l.price))::numeric, 0)
                                                             as p25_price,
  round((percentile_cont(0.5) within group (order by l.price))::numeric, 0)
                                                             as median_price,
  round((percentile_cont(0.75) within group (order by l.price))::numeric, 0)
                                                             as p75_price,
  max(l.price)                                               as max_price,
  round((percentile_cont(0.5) within group (order by l.year))::numeric, 0)
                                                             as median_year,
  round((percentile_cont(0.5) within group (order by l.mileage))::numeric, 0)
                                                             as median_mileage
from public.listings l
where l.motorcycle_id is not null
  and l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null
group by l.motorcycle_id;

grant select on public.model_price_summary to anon, authenticated;
