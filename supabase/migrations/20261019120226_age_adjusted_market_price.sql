-- How much a comparable's price is scaled to match another bike's age and
-- mileage. Positive year_diff = the bike being priced is newer; positive
-- km_diff = it has more kilometres. Unknowns count as no difference.
-- Clamped so an extreme pair can't produce an absurd estimate.
create function public.age_mileage_factor(
  p_year_diff   integer,
  p_km_diff     integer,
  p_per_year    numeric default 0.07,
  p_per_1000km  numeric default 0.004
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select greatest(0.6, least(1.6, exp(
    p_per_year * coalesce(p_year_diff, 0)
    - p_per_1000km * coalesce(p_km_diff, 0) / 1000.0
  )))
$$;

-- Fair value of each live listing: the median of the OTHER live listings of
-- the same model, each adjusted to this listing's year and mileage.
create view public.listing_fair_prices
with (security_invoker = true) as
select
  l.id                as listing_id,
  count(c.id)         as comparable_count,
  round((percentile_cont(0.5) within group (
    order by c.price * public.age_mileage_factor(l.year - c.year,
                                                 l.mileage - c.mileage)
  ))::numeric, 2)     as fair_price
from public.listings l
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

-- The price score now compares with the fair value instead of the model
-- median. Same columns as before, so the scoring function is unchanged.
drop view public.listing_price_scores;
create view public.listing_price_scores
with (security_invoker = true) as
select
  l.id                                                          as listing_id,
  l.motorcycle_id,
  l.price,
  f.fair_price                                                  as market_price,
  f.comparable_count                                            as listing_count,
  round((f.fair_price - l.price) / f.fair_price * 100, 1)       as pct_below_market,
  case when f.comparable_count >= 2
       then public.price_score(l.price, f.fair_price) end       as price_score,
  f.comparable_count >= 3                                       as is_reliable
from public.listings l
join public.listing_fair_prices f on f.listing_id = l.id
where l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null;

-- Risk's "price far below market" also uses the fair value.
drop view public.listing_risk_scores;
create view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.listing_fair_prices f on f.listing_id = l.id
cross join lateral public.risk_assessment(
  l.price,
  case when f.comparable_count >= 3 then f.fair_price end,
  l.year,
  l.mileage,
  l.description,
  l.location,
  l.details_checked_at is not null,
  coalesce(l.seller_type::text = 'private', false),
  l.registrations,
  l.service_book,
  l.origin,
  l.warranty_until
) r
where l.status in ('active', 'price_changed');

select public.recalculate_deal_scores();