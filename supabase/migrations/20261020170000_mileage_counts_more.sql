-- Mileage counts more in the fair value (Rafael, 2026-10-20). On the real
-- MT-07 market (72 listings) asking prices fall only ~0.25 % per 1000 km,
-- so a 2023 bike with 25 000 km was valued like its low-mileage peers.
-- From a buyer's side that is too little: the rate per 1000 km is now at
-- least 0.5 % (a model's own fitted rate still wins when higher).
--
-- Also: comparables without a year or mileage no longer count as having the
-- listing's own (they were adjusted by nothing).

create or replace view public.model_depreciation
with (security_invoker = true) as
with sample as (
  select
    l.motorcycle_id,
    l.year::numeric            as x1,
    l.mileage / 1000.0         as x2,
    ln(l.price::numeric)       as y
  from public.listings l
  where l.motorcycle_id is not null
    and l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.price > 0
    and l.year is not null
    and l.mileage is not null
),
moments as (
  select
    motorcycle_id,
    count(*)                    as n,
    covar_pop(x1, x1)           as s11,
    covar_pop(x2, x2)           as s22,
    covar_pop(x1, x2)           as s12,
    covar_pop(x1, y)            as s1y,
    covar_pop(x2, y)            as s2y
  from sample
  group by motorcycle_id
),
fit as (
  select
    motorcycle_id,
    n,
    case when n >= 30 and s11 * s22 - s12 * s12 > 0
         then (s22 * s1y - s12 * s2y) / (s11 * s22 - s12 * s12) end
      as raw_per_year,
    case when n >= 30 and s11 * s22 - s12 * s12 > 0
         then -(s11 * s2y - s12 * s1y) / (s11 * s22 - s12 * s12) end
      as raw_per_1000km
  from moments
)
select
  m.id                                                  as motorcycle_id,
  coalesce(f.n, 0)                                      as sample_count,
  f.raw_per_year is not null                            as is_fitted,
  case when f.raw_per_year is null then 0.04
       else round(((f.n * greatest(0, least(0.15, f.raw_per_year))
                    + 30 * 0.04) / (f.n + 30))::numeric, 5)
  end                                                   as per_year,
  -- A buyer's minimum: asking prices understate mileage (sellers of
  -- high-mileage bikes ask too much), so never less than 0.5 % per 1000 km.
  greatest(0.005,
    case when f.raw_per_year is null then 0.002
         else round(((f.n * greatest(0, least(0.01, f.raw_per_1000km))
                      + 30 * 0.002) / (f.n + 30))::numeric, 6)
    end)                                                as per_1000km
from public.motorcycles m
left join fit f on f.motorcycle_id = m.id;

create or replace view public.listing_fair_prices
with (security_invoker = true) as
select
  l.id                as listing_id,
  count(c.id)         as comparable_count,
  round((percentile_cont(0.5) within group (
    order by c.price * public.age_mileage_factor(l.year - c.year,
                                                 l.mileage - c.mileage,
                                                 d.per_year,
                                                 d.per_1000km)
  ))::numeric, 2)     as fair_price
from public.listings l
join public.model_depreciation d on d.motorcycle_id = l.motorcycle_id
join public.listings c
  on  c.motorcycle_id = l.motorcycle_id
  and c.id <> l.id
  and c.status in ('active', 'price_changed')
  and c.duplicate_of is null
  and c.price is not null
  -- A comparable without a year or mileage would count as the same age or
  -- mileage as the listing; leave it out when the listing has them.
  and (l.year is null or c.year is not null)
  and (l.mileage is null or c.mileage is not null)
where l.motorcycle_id is not null
  and l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null
group by l.id;

select public.recalculate_deal_scores();
