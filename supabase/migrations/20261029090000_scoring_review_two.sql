-- Second review of the calculations (15.33).
--
-- 1. Depreciation: the yearly rate was fitted together with the mileage
--    rate, then the mileage rate was raised to its floor (0.5 % per
--    1000 km) and blended, while the yearly rate kept the joint fit's value.
--    Older bikes have more km, so the age a higher mileage rate already
--    explains was counted again. The yearly rate is now the best fit given
--    the mileage rate actually used: (cov(year, ln p) + k cov(year, km)) /
--    var(year) (with k the fitted rate it is the joint fit itself).
-- 2. Typical time on the market: the median of the gone ads only, which
--    leaves out the ads still for sale (those that last longest), so it
--    came out short. Now the Kaplan-Meier median of gone and live ads, as
--    listing_time_to_sale: null while fewer than half have gone.
-- 3. Year score: counted in calendar years, so every bike lost 10 points
--    of it on 1 January. Now in days from mid-year registration, as the
--    normal mileage (age_score).

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
    n, s11, s12, s1y,
    case when n >= 30 and s11 * s22 - s12 * s12 > 0
         then -(s11 * s2y - s12 * s1y) / (s11 * s22 - s12 * s12) end
      as raw_per_1000km
  from moments
),
km as (
  select
    m.id as motorcycle_id,
    f.n, f.s11, f.s12, f.s1y,
    f.raw_per_1000km is not null as is_fitted,
    -- A buyer's minimum: asking prices understate mileage (sellers of
    -- high-mileage bikes ask too much), so never less than 0.5 % per 1000 km.
    greatest(0.005,
      case when f.raw_per_1000km is null then 0.002
           else round(((f.n * greatest(0, least(0.01, f.raw_per_1000km))
                        + 30 * 0.002) / (f.n + 30))::numeric, 6)
      end) as per_1000km
  from public.motorcycles m
  left join fit f on f.motorcycle_id = m.id
)
select
  k.motorcycle_id,
  coalesce(k.n, 0)                                      as sample_count,
  k.is_fitted,
  case when not k.is_fitted then 0.04
       -- The yearly rate given the mileage rate used (b2 = -per_1000km).
       else round(((k.n * greatest(0, least(0.15,
                      (k.s1y + k.per_1000km * k.s12) / k.s11))
                    + 30 * 0.04) / (k.n + 30))::numeric, 5)
  end                                                   as per_year,
  k.per_1000km
from km k;

create or replace view public.model_market_behaviour
with (security_invoker = true) as
with base as (
  select
    l.motorcycle_id,
    l.status,
    l.price,
    greatest(l.initial_price, l.price_before_drop) as initial_price,
    coalesce(l.published_at, l.first_seen_at) as listed_at,
    l.last_seen_at,
    l.status in ('removed', 'sold') as gone,
    greatest(0, extract(epoch from
      case when l.status in ('removed', 'sold') then l.last_seen_at
           else now() end
      - coalesce(l.published_at, l.first_seen_at)) / 86400) as days
  from public.listings l
  where l.motorcycle_id is not null
    and l.duplicate_of is null
)
select
  motorcycle_id,
  count(*) filter (where status in ('active', 'price_changed'))  as live_count,
  count(*) filter (where gone)                                   as gone_count,
  -- Kaplan-Meier: the ads still for sale count as lasting at least their age.
  round(public.median_days_remaining(
      array_agg(days) filter (where gone or status in ('active', 'price_changed')),
      array_agg(gone) filter (where gone or status in ('active', 'price_changed')),
      0))                                                        as median_days_to_gone,
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

-- 10 points a year of age, counted in days from mid-year registration
-- (decimal_year), so nothing jumps on 1 January; 100 until then.
create function public.age_score(
  p_year             integer,
  p_points_per_year  numeric default 10,
  p_reference        numeric default public.decimal_year()
)
returns smallint
language sql
stable
set search_path = ''
as $$
  select case
    when p_year is null then null
    else greatest(0, least(100, round(
      100 - greatest(0, p_reference - (p_year + 0.5)) * p_points_per_year
    )))::smallint
  end
$$;

revoke all on function public.age_score(integer, numeric, numeric)
  from public, anon, authenticated;

create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
set jit = off
as $$
declare
  n integer;
begin
  with dealers as (
    select d.dealer_key, d.bikes,
           public.dealer_score(d.bikes, d.relisted, d.sharp_changes,
                               d.missing_mileage, d.repeated) as score
    from public.dealer_reliability d
  ),
  scored as materialized (
    select
      l.id,
      ps.price_score,
      ps.market_price,
      ps.pct_below_market,
      ps.listing_count,
      coalesce(public.mileage_use_score(l.mileage, l.year),
               -- Hidden mileage: no better than an average-to-high one.
               case when l.year is not null then 50 end) as m_score,
      public.age_score(l.year)        as y_score,
      rs.risk_score,
      rs.reasons,
      coalesce(l.text_extras,
               public.listing_extras(l.variant, l.description)) as extras,
      dl.score as seller_score,
      dl.bikes as dealer_bikes
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    left join dealers dl
      on l.seller_type = 'dealer'
     and dl.dealer_key = lower(btrim(l.seller_name))
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
  ),
  combined as (
    select
      s.id,
      s.risk_score,
      case
        when c.deal_score > public.damage_cap(s.reasons)
          then public.damage_cap(s.reasons)
        else c.deal_score
      end as deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras),
        'valued_extras',        to_jsonb(public.valued_extras(s.extras)),
        'dealer_bikes',         s.dealer_bikes,
        'capped_for_damage',
          coalesce(c.deal_score > public.damage_cap(s.reasons), false)
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      cardinality(public.valued_extras(s.extras)), s.seller_score
    ) c
  )
  update public.listings l
  set deal_score      = c.deal_score,
      risk_score      = c.risk_score,
      score_breakdown = c.breakdown,
      scored_at       = now()
  from combined c
  where l.id = c.id;

  get diagnostics n = row_count;

  update public.listings
  set deal_score = null, risk_score = null,
      score_breakdown = null, scored_at = null
  where (status not in ('active', 'price_changed')
         or duplicate_of is not null
         or motorcycle_id is null)
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;

select public.recalculate_deal_scores();
