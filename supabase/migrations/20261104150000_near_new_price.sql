-- Nearly new bikes (N.51): a bike of 2 years or less (from mid-year) with
-- at most half the normal mileage is also priced against a new one
-- (motorcycles.new_price_reference); the price slice takes the better of
-- that and the market comparison. A bike whose text tells of damage keeps
-- the market comparison only. The breakdown gains new_price,
-- pct_below_new and price_from_new.

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
      l.price,
      ps.market_price,
      public.damage_allowance(rs.reasons) as allowance,
      ps.pct_below_market,
      ps.listing_count,
      -- Nearly new (2 years or less from mid-year, at most half the normal
      -- mileage): also compared with the price of a new one (N.51).
      case when l.year is not null
            and public.decimal_year() - (l.year + 0.5) <= 2
            and public.mileage_use_score(l.mileage, l.year) = 100
           then m.new_price_reference
      end as new_price,
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
    join public.motorcycles m on m.id = l.motorcycle_id
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
      s.allowance,
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
        'damage_allowance',     nullif(s.allowance, 0),
        'damaged_value',
          case when s.allowance > 0 then round(s.damaged_value) end,
        'pct_below_damaged_value',
          case when s.allowance > 0 and s.damaged_value > 0
               then round((s.damaged_value - s.price) / s.damaged_value * 100, 1)
          end,
        'new_price',            round(s.new_price),
        'pct_below_new',
          case when s.new_price > 0
               then round((s.new_price - s.price) / s.new_price * 100, 1)
          end,
        'price_from_new',       coalesce(s.new_score > s.market_score
                                         or (s.market_score is null
                                             and s.new_score is not null), false),
        'capped_for_damage',
          coalesce(c.deal_score > public.damage_cap(s.reasons), false)
      ) as breakdown
    from (
      -- The price is scored against the value of the bike with its damage,
      -- so a damaged bike well below that still ranks high.
      -- A nearly new bike takes the better of that and its price against a
      -- new one's (not a damaged one: the damage is unseen).
      select s1.*,
             case when s1.new_score > s1.market_score
                    or s1.market_score is null
                  then coalesce(s1.new_score, s1.market_score)
                  else s1.market_score
             end as price_score
      from (
        select s0.*,
               s0.market_price * (1 - s0.allowance) as damaged_value,
               case when s0.listing_count >= 3
                    then public.price_score(s0.price,
                           s0.market_price * (1 - s0.allowance), 2.5)
               end as market_score,
               case when s0.allowance = 0 and s0.new_price > 0
                    then public.price_score(s0.price, s0.new_price, 2.5)
               end as new_score
        from scored s0
      ) s1
    ) s
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

revoke all on function public.recalculate_deal_scores()
  from public, anon, authenticated;

select public.recalculate_deal_scores();
