-- Damaged bikes (15.34). A bike whose text tells of an accident or a
-- repair to do was capped at a Deal Score of 50, however cheap: a bike
-- 25 % below an undamaged one could be a good buy to repair. Now its
-- price is compared with the estimate less a repair allowance
-- (damage_allowance: accident 15 %, as bike_value's accident; repair to
-- do 10 %; both 20 %), in the price score and in the risk's price
-- signals, and the cap is 79: a damaged bike can rank high but is never
-- an excellent opportunity (score 80), since the damage is unseen.
-- The breakdown's market_price and pct_below_market stay the undamaged
-- estimate; damage_allowance, damaged_value and pct_below_damaged_value
-- are added.

create function public.damage_allowance(p_reasons text[])
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_reasons @> array['possible_accident', 'needs_repair'] then 0.20
    when 'possible_accident' = any(p_reasons) then 0.15
    when 'needs_repair' = any(p_reasons) then 0.10
    else 0
  end
$$;

revoke all on function public.damage_allowance(text[]) from public, anon, authenticated;

create or replace function public.damage_cap(p_reasons text[])
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case when p_reasons && array['possible_accident', 'needs_repair']
              then 79::smallint end
$$;

create or replace function public.risk_from_signals(
  p_price          numeric,
  p_market_price   numeric,
  p_year           integer,
  p_mileage        integer,
  p_description    text,
  p_location       text,
  p_details_known  boolean,
  p_private_seller boolean,
  p_registrations  integer,
  p_service_book   boolean,
  p_origin         text,
  p_warranty_until date,
  p_relists        integer,
  p_on_sale_since  timestamptz,
  p_text_signals   text[]
)
returns table (risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  -- Measured against the value of the bike with its damage
  -- (damage_allowance): a damaged bike priced like one isn't suspicious.
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (m.value - p_price) / m.value * 100
    end as below
    from (select p_market_price
                 * (1 - public.damage_allowance(p_text_signals)) as value) m
  ),
  signals(code, points) as (
    select 'price_far_below_market'::text, 45 from pct where below >= 25
    union all
    select 'price_below_market', 25 from pct where below >= 15 and below < 25
    union all
    select 'possible_accident', 30
    where 'possible_accident' = any(p_text_signals)
    union all
    select 'needs_repair', 20
    where 'needs_repair' = any(p_text_signals)
    union all
    select 'cosmetic_damage', 5
    where 'cosmetic_damage' = any(p_text_signals)
    union all
    select 'photos_reused', 10
    where 'photos_reused' = any(p_text_signals)
    union all
    select 'no_mileage', 15 where p_mileage is null
    union all
    select 'no_year', 10 where p_year is null
    union all
    -- A placeholder ("0", "1", "10") on a bike three or more years old, or
    -- far more than anyone rides in a year (bikes average 3-6 000 km). The
    -- age counts from mid-year registration in days, at least one year, as
    -- expected_mileage does.
    select 'suspicious_mileage', 10
    where p_mileage is not null and p_year is not null
      and (
        (p_mileage < 100
          and p_year <= extract(year from current_date)::integer - 3)
        or p_mileage::numeric
           / greatest(1, public.decimal_year() - (p_year + 0.5))
           > 25000
      )
    union all
    -- Only meaningful once the page was read, and only for private sellers:
    -- dealers rarely write more than boilerplate.
    select 'thin_description', 10
    where p_details_known and p_private_seller
      and char_length(btrim(coalesce(p_description, ''))) < 40
    union all
    select 'no_location', 5
    where nullif(btrim(coalesce(p_location, '')), '') is null
    union all
    select 'many_owners', 15 where p_registrations >= 3
    union all
    select 'no_service_book', 10 where p_service_book = false
    union all
    select 'imported', 10 where p_origin is not null and p_origin <> 'national'
    union all
    -- The text says something else than the ad's own fields.
    select c, 10 from unnest(public.text_contradictions(
      p_description, p_year, p_mileage, p_origin, p_service_book)) c
    union all
    -- A bike put up again after its ad went (mark_relists): it did not sell
    -- at that price. More when it happened twice or the bike has been on
    -- sale for over 90 days counting the earlier ads.
    select 'relisted_often', 10
    where p_relists >= 2
       or (p_relists = 1 and p_on_sale_since < now() - interval '90 days')
    union all
    select 'relisted', 5
    where p_relists = 1
      and (p_on_sale_since is null or p_on_sale_since >= now() - interval '90 days')
    union all
    -- An A2 (35 kW) version, still held back or unlocked (power_version).
    select v, case v when 'a2_limited' then 15 else 10 end
    from unnest(p_text_signals) v
    where v in ('a2_limited', 'a2_unlocked')
    union all
    -- The ad's field, or the text when the field is empty.
    select 'first_owner', -5
    where p_registrations = 1
       or (p_registrations is null
           and 'single_owner_in_text' = any(p_text_signals))
    union all
    select 'service_book', -5 where p_service_book
    union all
    select 'under_warranty', -10 where p_warranty_until >= current_date
  )
  select
    greatest(0, least(100, coalesce(sum(points), 0)))::smallint,
    coalesce(array_agg(code order by points desc, code), '{}'::text[])
  from signals
$$;


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
        'capped_for_damage',
          coalesce(c.deal_score > public.damage_cap(s.reasons), false)
      ) as breakdown
    from (
      -- The price is scored against the value of the bike with its damage,
      -- so a damaged bike well below that still ranks high.
      select s0.*,
             s0.market_price * (1 - s0.allowance) as damaged_value,
             case when s0.listing_count >= 3
                  then public.price_score(s0.price,
                         s0.market_price * (1 - s0.allowance), 2.5)
             end as price_score
      from scored s0
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

select public.recalculate_deal_scores();
