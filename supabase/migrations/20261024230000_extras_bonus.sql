-- Extras weigh less, and only the ones worth money count (Rafael,
-- 2026-10-22: a bike one year newer with fewer kilometres scored below an
-- older one with more, because the older ad named 5 extras and the newer 2).
--
-- At 2 points each, up to 10, three extras more (6 points) outweighed the
-- whole year/mileage slice's edge: a year newer is 10 points of the year
-- score, 3 of the slice, under 1 of the Deal Score; a quarter less of the
-- normal mileage is about 3. And most extras found are small or a matter
-- of taste (a USB socket, LED indicators, a short plate holder, bar-end
-- mirrors), named more often by sellers who write longer ads.
--
-- Now 1 point per extra a buyer would pay for (quickshifter, aftermarket
-- exhaust, luggage, heated grips, upgraded suspension, cruise control,
-- steering damper, new tyres), at most 3: a tiebreaker between bikes that
-- are otherwise alike, never more than about a year's difference. Every
-- extra is still read, listed on the ad and offered as a saved-search
-- filter (listing_extras is unchanged).

create function public.valued_extras(p_extras text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(e order by e), '{}'::text[])
  from unnest(p_extras) e
  where e = any (array['quickshifter', 'exhaust', 'luggage', 'heated_grips',
                       'suspension', 'cruise_control', 'steering_damper',
                       'new_tyres'])
$$;

revoke all on function public.valued_extras(text[]) from public, anon, authenticated;

-- The same combiner, 1 point per extra and at most 3 (p_extras is now the
-- number of valued extras).
create or replace function public.combine_deal_score(
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
  p_points_per_extra integer default 1,
  p_max_extras      integer default 3,
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

-- As in 20261024140000_dealer_score.sql, counting only the valued extras;
-- the breakdown keeps every extra found and names the valued ones.
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
        'valued_extras',        to_jsonb(public.valued_extras(s.extras)),
        'dealer_bikes',         s.dealer_bikes
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
