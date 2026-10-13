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
  where status not in ('active', 'price_changed')
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;