-- The price of a new bike from the dealers' new bikes on sale (N.58): no
-- one types it any more, and two accounts can't set different ones. A
-- model's new price is the median asking price of the live dealer ads of
-- this year's or last year's bike with 100 km or less, none damaged or
-- still to be legalised, from 3 such ads; refreshed before each scoring.
-- The typed price (`new_price_reference`, admins only now) is the
-- fallback while a model has fewer.

alter table public.motorcycles
  add column new_price_from_ads numeric(10,2),
  add column new_price_ad_count smallint;

comment on column public.motorcycles.new_price_from_ads is
  'Median price of the live dealer ads of a new bike of this model (new_bike_ad), from 3 ads; refresh_new_prices_from_ads.';
comment on column public.motorcycles.new_price_ad_count is
  'How many ads new_price_from_ads is the median of.';

-- An ad of a new bike in a shop: a dealer's, this year's or last year's,
-- 100 km or less, a real price, nothing in the text that lowers its price.
create or replace function public.new_bike_ad(
  p_year integer, p_mileage integer, p_price numeric,
  p_seller_type public.seller_type, p_signals text[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_seller_type = 'dealer'
     and p_price >= 300
     and p_year >= extract(year from now() at time zone 'Europe/Lisbon')::int - 1
     and p_mileage is not null and p_mileage <= 100
     and not coalesce(p_signals && array['possible_accident', 'needs_repair',
                                         'cosmetic_damage', 'not_legalised',
                                         'not_legalised_outside_eu'], false)
$$;

revoke all on function public.new_bike_ad(integer, integer, numeric, public.seller_type, text[])
  from public, anon, authenticated;

create or replace function public.refresh_new_prices_from_ads()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with ads as (
    select l.motorcycle_id,
           count(*)::smallint as ad_count,
           round(percentile_cont(0.5) within group (order by l.price)::numeric)
             as median_price
    from public.listings l
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
      and public.new_bike_ad(l.year, l.mileage, l.price, l.seller_type,
            coalesce(l.text_signals,
                     public.description_signals(l.variant, l.description)))
    group by l.motorcycle_id
    having count(*) >= 3
  ),
  wanted as (
    select m.id, a.median_price, a.ad_count
    from public.motorcycles m
    left join ads a on a.motorcycle_id = m.id
  )
  update public.motorcycles m
  set new_price_from_ads = w.median_price,
      new_price_ad_count = w.ad_count
  from wanted w
  where m.id = w.id
    and (m.new_price_from_ads is distinct from w.median_price
         or m.new_price_ad_count is distinct from w.ad_count);

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.refresh_new_prices_from_ads()
  from public, anon, authenticated;

-- Only an admin types a new price now (it is everyone's fallback).
create or replace function public.set_model_new_price(
  p_motorcycle_id uuid, p_price numeric, p_checked_at date default current_date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();

  if p_price is not null and (p_price <= 0 or p_price > 200000) then
    raise exception 'Price % is out of range', p_price using errcode = '22023';
  end if;

  update public.motorcycles
  set new_price_reference  = p_price,
      new_price_checked_at = case when p_price is null then null
                                  else coalesce(p_checked_at, current_date) end,
      updated_at           = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
end;
$$;

create or replace view public.listing_new_price_comparison
with (security_invoker = true) as
select l.id as listing_id,
       l.motorcycle_id,
       l.price as used_price,
       coalesce(m.new_price_from_ads, m.new_price_reference) as new_price,
       coalesce(m.new_price_from_ads, m.new_price_reference) - l.price as difference,
       round((coalesce(m.new_price_from_ads, m.new_price_reference) - l.price)
             / nullif(coalesce(m.new_price_from_ads, m.new_price_reference), 0) * 100, 1)
         as difference_pct
from public.listings l
join public.motorcycles m on m.id = l.motorcycle_id
where l.price is not null
  and coalesce(m.new_price_from_ads, m.new_price_reference) is not null;

-- Scoring refreshes the new prices first and prefers the ads' one.
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
  perform public.refresh_new_prices_from_ads();

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
      -- Not yet legalised in Portugal (N.52): what that costs comes off.
      public.legalisation_cost(
        rs.reasons, coalesce(m.engine_cc_max, m.engine_cc_min),
        case when l.price >= 300 then l.price else ps.market_price end,
        l.year, l.mileage) as legalisation,
      ps.pct_below_market,
      ps.listing_count,
      -- Nearly new (2 years or less from mid-year, at most half the normal
      -- mileage): also compared with the price of a new one (N.51).
      case when l.year is not null
            and public.decimal_year() - (l.year + 0.5) <= 2
            and public.mileage_use_score(l.mileage, l.year) = 100
           then coalesce(m.new_price_from_ads, m.new_price_reference)
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
      -- least ignores nulls: the lower of the caps that apply.
      coalesce(least(c.deal_score,
                     public.damage_cap(s.reasons),
                     public.legalisation_cap(s.reasons)),
               c.deal_score) as deal_score,
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
        'legalisation_cost',
          case when s.legalisation > 0 then round(s.legalisation) end,
        'legalised_value',
          case when s.legalisation > 0 then round(s.compared_value) end,
        'pct_below_legalised_value',
          case when s.legalisation > 0 and s.compared_value > 0
               then round((s.compared_value - s.price) / s.compared_value * 100, 1)
          end,
        'capped_for_legalisation',
          coalesce(c.deal_score > public.legalisation_cap(s.reasons), false),
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
      -- new one's (not a damaged one: the damage is unseen; nor one still
      -- to be legalised).
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
                           greatest(s0.compared_value, 1), 2.5)
               end as market_score,
               case when s0.allowance = 0 and s0.legalisation = 0
                     and s0.new_price > 0
                    then public.price_score(s0.price, s0.new_price, 2.5)
               end as new_score
        from (
          -- The value the price is compared with: the estimate less a
          -- repair allowance and what legalising costs.
          select sc.*,
                 sc.market_price * (1 - sc.allowance) - sc.legalisation
                   as compared_value
          from scored sc
        ) s0
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

select public.refresh_new_prices_from_ads();
select public.recalculate_deal_scores();
