-- Stored scores on listings (deal_score already exists from 2.5).
alter table public.listings
  add column risk_score      smallint check (risk_score between 0 and 100),
  add column score_breakdown jsonb,
  add column scored_at       timestamptz;

-- Pure combiner: weighted average of the slices that have data.
-- Weights default to the concept doc; the three slices with no data yet
-- (version/equipment 15, seller/confidence 10, market behaviour 10) are skipped.
create function public.combine_deal_score(
  p_price_score     integer,
  p_mileage_score   integer,
  p_year_score      integer,
  p_risk_score      integer,
  p_w_price         numeric default 35,
  p_w_year_mileage  numeric default 20,
  p_w_risk          numeric default 10,
  p_mileage_share   numeric default 0.7
)
returns table (deal_score smallint, breakdown jsonb)
language sql
immutable
set search_path = ''
as $$
  with slices(name, weight, score) as (
    values
      ('price', p_w_price, p_price_score::numeric),
      ('year_mileage', p_w_year_mileage,
        case
          when p_mileage_score is not null and p_year_score is not null
            then p_mileage_share * p_mileage_score
               + (1 - p_mileage_share) * p_year_score
          else coalesce(p_mileage_score, p_year_score)::numeric
        end),
      ('risk', p_w_risk,
        case when p_risk_score is null then null else 100 - p_risk_score end::numeric)
  ),
  used as (select * from slices where score is not null)
  select
    case when count(*) = 0 then null
         else round(sum(weight * score) / sum(weight))::smallint end,
    jsonb_build_object(
      'slices_used',  count(*),
      'slices_total', 6,
      'scores',  coalesce(jsonb_object_agg(name, round(score, 1)), '{}'::jsonb),
      'weights', coalesce(jsonb_object_agg(name, weight), '{}'::jsonb)
    )
  from used
$$;

-- Recompute and store scores for every live listing.
-- Call it after each collector run; returns how many listings were scored.
create function public.recalculate_deal_scores()
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
      public.mileage_score(l.mileage) as m_score,
      public.year_score(l.year)       as y_score,
      rs.risk_score
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    where l.status in ('active', 'price_changed')
  ),
  combined as (
    select s.id, s.risk_score, c.deal_score, c.breakdown
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

  -- Removed/sold listings carry no score.
  update public.listings
  set deal_score = null, risk_score = null,
      score_breakdown = null, scored_at = null
  where status not in ('active', 'price_changed')
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;

-- Only the backend (service role) and the dashboard should run it.
revoke all on function public.recalculate_deal_scores()
  from public, anon, authenticated;