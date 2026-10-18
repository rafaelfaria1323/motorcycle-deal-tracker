-- Market prices, price scores and risk ignore duplicates, so one bike
-- posted twice counts once.
create or replace view public.model_market_stats
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
  and duplicate_of is null
group by motorcycle_id;

create or replace view public.listing_price_scores
with (security_invoker = true) as
select
  l.id                                                         as listing_id,
  l.motorcycle_id,
  l.price,
  s.median_price                                               as market_price,
  s.listing_count,
  round((s.median_price - l.price) / s.median_price * 100, 1)  as pct_below_market,
  public.price_score(l.price, s.median_price)                  as price_score,
  s.listing_count >= 3                                         as is_reliable
from public.listings l
join public.model_market_stats s on s.motorcycle_id = l.motorcycle_id
where l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null;

create or replace view public.listing_risk_scores
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
where l.status in ('active', 'price_changed')
  and l.duplicate_of is null;

-- Scores are only stored for live, non-duplicate listings.
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with scored as (
    select
      l.id,
      ps.price_score,
      ps.market_price,
      ps.pct_below_market,
      ps.listing_count,
      public.mileage_score(l.mileage) as m_score,
      public.year_score(l.year)       as y_score,
      rs.risk_score,
      rs.reasons
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
  ),
  combined as (
    select
      s.id,
      s.risk_score,
      c.deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[]))
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score
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
  where (status not in ('active', 'price_changed') or duplicate_of is not null)
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;