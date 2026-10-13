-- Risk component (0-100, higher = riskier) plus the reasons that fired.
-- Risk lowers confidence; it never declares a listing fraudulent.
create function public.risk_assessment(
  p_price         numeric,
  p_market_price  numeric,
  p_year          integer,
  p_mileage       integer,
  p_description   text,
  p_location      text
)
returns table (risk_score smallint, reasons text[])
language sql
immutable
set search_path = ''
as $$
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (p_market_price - p_price) / p_market_price * 100
    end as below
  ),
  signals(code, points) as (
    select 'price_far_below_market'::text, 45 from pct where below >= 25
    union all
    select 'price_below_market', 25 from pct where below >= 15 and below < 25
    union all
    -- Crude text match; phrases like "sem sinistros" are removed first.
    select 'possible_accident', 30
    where regexp_replace(
            lower(coalesce(p_description, '')),
            'sem\s+(sinistros?|acidentes?|danos?)', '', 'g'
          ) ~ '(sinistr|acident|batid[ao]|bateu)'
    union all
    select 'no_mileage', 15 where p_mileage is null
    union all
    select 'no_year', 10 where p_year is null
    union all
    select 'thin_description', 10
    where char_length(btrim(coalesce(p_description, ''))) < 40
    union all
    select 'no_location', 5
    where nullif(btrim(coalesce(p_location, '')), '') is null
  )
  select
    least(100, coalesce(sum(points), 0))::smallint,
    coalesce(array_agg(code order by points desc, code), '{}'::text[])
  from signals
$$;

-- Risk per live listing. The market price is only used when the model has
-- at least 3 live listings, so a tiny sample can't flag a normal price.
create view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.model_market_stats s on s.motorcycle_id = l.motorcycle_id
cross join lateral public.risk_assessment(
  l.price,
  case when s.listing_count >= 3 then s.median_price end,
  l.year,
  l.mileage,
  l.description,
  l.location
) r
where l.status in ('active', 'price_changed');