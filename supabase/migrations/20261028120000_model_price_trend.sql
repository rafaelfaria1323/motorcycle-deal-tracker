-- Price trends per model (10.3 / 15.8): the median asking price of each
-- model, week by week, over the last 12 weeks.
--
-- A week's listings are the model's non-duplicate ads seen in it (first
-- seen before the week ended, last seen after it began), each at the last
-- price recorded by the week's end. Ads under 300 € are left out, as in the
-- fair price.
--
-- The plain median moves when the mix moves (a week with more new bikes
-- looks dearer), so each price is also brought to the model's typical bike
-- of today (median year and mileage of the live listings) with the model's
-- own depreciation rates, as the fair price does with comparables. The
-- app's trend reads that adjusted median.
create view public.model_price_trend
with (security_invoker = true) as
with weeks as (
  select w::timestamptz as week_start
  from generate_series(
    date_trunc('week', now()) - interval '11 weeks',
    date_trunc('week', now()),
    interval '1 week'
  ) w
),
seen as (
  select
    l.motorcycle_id,
    wk.week_start,
    l.year,
    l.mileage,
    coalesce((
      select h.price
      from public.listing_price_history h
      where h.listing_id = l.id
        and h.observed_at < wk.week_start + interval '1 week'
      order by h.observed_at desc
      limit 1
    ), l.price) as price
  from public.listings l
  join weeks wk
    on l.first_seen_at < wk.week_start + interval '1 week'
   and l.last_seen_at >= wk.week_start
  where l.motorcycle_id is not null
    and l.duplicate_of is null
),
adjusted as (
  select
    s.motorcycle_id,
    s.week_start,
    s.price,
    s.price * public.age_mileage_factor(
      (ps.median_year - s.year)::integer,
      (ps.median_mileage - s.mileage)::integer,
      coalesce(d.per_year, 0.04),
      coalesce(d.per_1000km, 0.002)
    ) as adjusted_price
  from seen s
  left join public.model_price_summary ps on ps.motorcycle_id = s.motorcycle_id
  left join public.model_depreciation d on d.motorcycle_id = s.motorcycle_id
  where s.price >= 300
)
select
  motorcycle_id,
  week_start::date                                                  as week_start,
  count(*)                                                          as listing_count,
  round((percentile_cont(0.5) within group (order by price))::numeric, 0)
                                                                    as median_price,
  round((percentile_cont(0.5) within group (order by adjusted_price))::numeric, 0)
                                                                    as median_adjusted_price
from adjusted
group by motorcycle_id, week_start;

grant select on public.model_price_trend to anon, authenticated;
