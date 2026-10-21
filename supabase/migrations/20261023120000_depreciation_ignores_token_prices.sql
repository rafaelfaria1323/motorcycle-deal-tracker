-- Ads under 300 € (parts, deposits, typos) are never comparables
-- (listing_fair_prices) and no longer bend the model's depreciation fit:
-- one 1 € ad (ln 1 = 0) moved an MT-07's 4 %/year to 10 %/year.

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
    and l.price >= 300
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

select public.recalculate_deal_scores();
