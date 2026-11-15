-- B.1 (docs/bug-hunt.md 1.1): a typed ad's title is read for its risk
-- signals and equipment, as a stored ad's version or title is: a
-- Facebook or CustoJusto title often says what the text doesn't ("MT-07
-- 35 kW A2", "por legalizar", "com Akrapovic"). typed_ad_score takes it as
-- p_variant and passes it to description_signals and listing_extras.
drop function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer);

create function public.typed_ad_score(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer,
  p_price numeric,
  p_private_seller boolean,
  p_registrations integer default null,
  p_service_book boolean default null,
  p_warranty boolean default false,
  p_damage text default null,
  p_description text default null,
  p_from_year integer default null,
  p_to_year integer default null,
  p_variant text default null
)
returns table(deal_score smallint, risk_score smallint, breakdown jsonb)
language sql
stable
security definer
set search_path = ''
set jit = off
as $$
  with model as (
    select m.id, coalesce(m.engine_cc_max, m.engine_cc_min) as engine_cc,
           coalesce(m.new_price_from_ads, m.new_price_reference) as new_price
    from public.motorcycles m
    where m.id = p_motorcycle_id
  ),
  input as (
    select
      md.*,
      nullif(btrim(coalesce(p_description, '')), '') as description,
      v.comparable_count,
      v.fair_price,
      (select coalesce(array_agg(distinct s), '{}'::text[])
       from unnest(
         public.description_signals(nullif(btrim(coalesce(p_variant, '')), ''), p_description)
         || case p_damage
              when 'accident' then array['possible_accident']
              when 'dropped' then array['cosmetic_damage']
              else '{}'::text[]
            end) s) as signals
    from model md
    cross join lateral public.bike_value_in_years(md.id, p_year, p_mileage, p_from_year, p_to_year) v
  ),
  risk as (
    select i.*, r.risk_score, r.reasons
    from input i
    cross join lateral public.risk_from_signals(
      p_price,
      case when i.comparable_count >= 3 then i.fair_price end,
      p_year, p_mileage, i.description,
      -- The place isn't asked: no "no location" sign.
      'typed',
      -- A pasted description is the ad's whole text.
      i.description is not null,
      coalesce(p_private_seller, false),
      p_registrations, p_service_book,
      null,
      case when p_warranty then current_date + 1 end,
      0, null,
      i.signals) r
  ),
  scored as (
    select
      r.*,
      public.damage_allowance(r.reasons) as allowance,
      public.legalisation_cost(
        r.reasons, r.engine_cc,
        case when p_price >= 300 then p_price else r.fair_price end,
        p_year, p_mileage) as legalisation,
      case when p_year is not null
            and public.decimal_year() - (p_year + 0.5) <= 2
            and public.mileage_use_score(p_mileage, p_year) = 100
           then r.new_price
      end as near_new_price,
      coalesce(public.mileage_use_score(p_mileage, p_year),
               case when p_year is not null then 50 end) as m_score,
      public.age_score(p_year) as y_score,
      public.listing_extras(nullif(btrim(coalesce(p_variant, '')), ''), p_description) as extras
    from risk r
  ),
  priced as (
    select s1.*,
           case when s1.new_score > s1.market_score or s1.market_score is null
                then coalesce(s1.new_score, s1.market_score)
                else s1.market_score
           end as price_score
    from (
      select s0.*,
             case when s0.comparable_count >= 3 and s0.fair_price > 0
                  then public.price_score(p_price, greatest(s0.compared_value, 1), 2.5)
             end as market_score,
             case when s0.allowance = 0 and s0.legalisation = 0
                   and s0.near_new_price > 0
                  then public.price_score(p_price, s0.near_new_price, 2.5)
             end as new_score
      from (
        select s.*,
               s.fair_price * (1 - s.allowance) as damaged_value,
               s.fair_price * (1 - s.allowance) - s.legalisation as compared_value
        from scored s
      ) s0
    ) s1
  )
  select
    coalesce(least(c.deal_score,
                   public.damage_cap(p.reasons),
                   public.legalisation_cap(p.reasons)),
             c.deal_score),
    p.risk_score,
    c.breakdown || jsonb_build_object(
      'market_price',         p.fair_price,
      'pct_below_market',
        case when p.fair_price > 0
             then round((p.fair_price - p_price) / p.fair_price * 100, 1)
        end,
      'market_listing_count', p.comparable_count,
      'risk_reasons',         to_jsonb(coalesce(p.reasons, '{}'::text[])),
      'extras',               to_jsonb(p.extras),
      'valued_extras',        to_jsonb(public.valued_extras(p.extras)),
      'damage_allowance',     nullif(p.allowance, 0),
      'damaged_value',
        case when p.allowance > 0 then round(p.damaged_value) end,
      'pct_below_damaged_value',
        case when p.allowance > 0 and p.damaged_value > 0
             then round((p.damaged_value - p_price) / p.damaged_value * 100, 1)
        end,
      'new_price',            round(p.near_new_price),
      'pct_below_new',
        case when p.near_new_price > 0
             then round((p.near_new_price - p_price) / p.near_new_price * 100, 1)
        end,
      'legalisation_cost',
        case when p.legalisation > 0 then round(p.legalisation) end,
      'legalised_value',
        case when p.legalisation > 0 then round(p.compared_value) end,
      'pct_below_legalised_value',
        case when p.legalisation > 0 and p.compared_value > 0
             then round((p.compared_value - p_price) / p.compared_value * 100, 1)
        end,
      'capped_for_legalisation',
        coalesce(c.deal_score > public.legalisation_cap(p.reasons), false),
      'price_from_new',
        coalesce(p.new_score > p.market_score
                 or (p.market_score is null and p.new_score is not null), false),
      'capped_for_damage',
        coalesce(c.deal_score > public.damage_cap(p.reasons), false)
    )
  from priced p
  cross join lateral public.combine_deal_score(
    p.price_score, p.m_score, p.y_score, p.risk_score,
    cardinality(public.valued_extras(p.extras)), null
  ) c
  where p_price >= 300
$$;

revoke all on function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer, text) from public, anon, authenticated;
-- Only works out figures from what is already readable: open to visitors,
-- as bike_value is.
grant execute on function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer, text) to anon, authenticated;
