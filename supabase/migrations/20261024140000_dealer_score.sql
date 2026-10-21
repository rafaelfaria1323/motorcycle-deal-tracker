-- Dealer reliability in the Deal Score (15.7, 4.7): the 10 % "seller" slice.
--
-- A dealer's score comes from the figures of dealer_reliability, each a
-- share of its bikes: 100 minus 100 x (relisted + sharp price changes +
-- repeated ads + half the ads without mileage) / bikes, kept within 0..100.
-- Missing mileage counts half: dealers often leave it out on bikes in
-- stock with next to none. Price drops never count against a dealer (they
-- are good for the buyer).
--
-- Only dealers with 5 bikes or more are scored (the app's minDealerBikes):
-- below that, and for private sellers (no name is ever stored), the slice
-- is skipped and the score renormalizes over the others, as for any slice
-- without data. A neutral 50 instead would pull every good private-seller
-- score down.

create function public.dealer_score(
  p_bikes           bigint,
  p_relisted        bigint,
  p_sharp_changes   bigint,
  p_missing_mileage bigint,
  p_repeated        bigint,
  p_min_bikes       integer default 5
)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(p_bikes, 0) >= p_min_bikes then
      greatest(0, least(100, round(100 - 100.0 * (
        coalesce(p_relisted, 0)
        + coalesce(p_sharp_changes, 0)
        + coalesce(p_repeated, 0)
        + 0.5 * coalesce(p_missing_mileage, 0)
      ) / p_bikes)))::smallint
  end
$$;

revoke all on function public.dealer_score(bigint, bigint, bigint, bigint, bigint, integer)
  from public, anon, authenticated;

-- The combiner gains the seller slice (the argument list changes, so the
-- old one goes first; recalculate_deal_scores below is its only caller).
drop function public.combine_deal_score(
  integer, integer, integer, integer, integer,
  numeric, numeric, numeric, numeric, integer, integer, integer
);

create function public.combine_deal_score(
  p_price_score     integer,
  p_mileage_score   integer,
  p_year_score      integer,
  p_risk_score      integer,
  p_extras          integer default 0,
  p_seller_score    integer default null,
  p_w_price         numeric default 35,
  p_w_year_mileage  numeric default 20,
  p_w_risk          numeric default 10,
  p_w_seller        numeric default 10,
  p_mileage_share   numeric default 0.7,
  p_points_per_extra integer default 2,
  p_max_extras      integer default 5,
  p_without_price   integer default 70
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
        case when p_risk_score is null then null else 100 - p_risk_score end::numeric),
      ('seller', p_w_seller, p_seller_score::numeric)
  ),
  used as (select * from slices where score is not null),
  base as (
    select
      count(*) as n,
      case when count(*) > 0 then sum(weight * score) / sum(weight) end as score,
      bool_or(name = 'price') as has_price,
      coalesce(jsonb_object_agg(name, round(score, 1)), '{}'::jsonb) as scores,
      coalesce(jsonb_object_agg(name, weight), '{}'::jsonb) as weights
    from used
  ),
  bonus as (
    select p_points_per_extra * least(greatest(coalesce(p_extras, 0), 0), p_max_extras)
             as points
  )
  select
    case when b.n = 0 then null
         else round(least(
                case when b.has_price then 100 else p_without_price end,
                b.score + x.points))::smallint
    end,
    jsonb_build_object(
      'slices_used',     b.n,
      'slices_total',    4,
      'scores',          b.scores,
      'weights',         b.weights,
      'equipment_bonus', x.points,
      'capped_without_price',
        b.n > 0 and not coalesce(b.has_price, false)
        and b.score + x.points > p_without_price
    )
  from base b, bonus x
$$;

create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
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
  scored as (
    select
      l.id,
      ps.price_score,
      ps.market_price,
      ps.pct_below_market,
      ps.listing_count,
      coalesce(public.mileage_use_score(l.mileage, l.year),
               -- Hidden mileage: no better than an average-to-high one.
               case when l.year is not null then 50 end) as m_score,
      public.year_score(l.year)       as y_score,
      rs.risk_score,
      rs.reasons,
      public.listing_extras(l.variant, l.description) as extras,
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
      c.deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras),
        'dealer_bikes',         s.dealer_bikes
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      cardinality(s.extras), s.seller_score
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
