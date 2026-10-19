-- Each model's own depreciation, fitted on its live listings.
--
-- ln(price) = a + per_year * year - per_1000km * km/1000, by least squares
-- over live, non-duplicate listings with a price, year and mileage. With
-- at least 30 of them the fit is blended with the general rates (4 % a
-- year, 0.2 % per 1000 km), weighted by count: 30 listings count half,
-- 90 count three quarters. Below 30 the general rates apply. Fits are
-- clamped to 0-15 % a year and 0-1 % per 1000 km, since year and mileage
-- move together and a small market can produce odd pairs.
create view public.model_depreciation
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
  case when f.raw_per_year is null then 0.002
       else round(((f.n * greatest(0, least(0.01, f.raw_per_1000km))
                    + 30 * 0.002) / (f.n + 30))::numeric, 6)
  end                                                   as per_1000km
from public.motorcycles m
left join fit f on f.motorcycle_id = m.id;

-- Same fair value as before, now with the model's own rates.
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
where l.motorcycle_id is not null
  and l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null
group by l.id;

select public.recalculate_deal_scores();
