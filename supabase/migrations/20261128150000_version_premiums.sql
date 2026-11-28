-- Versions in the fair value (N.136).
--
-- A listing's fair value was the median of its model's other ads whatever
-- their version: an E-Clutch CB650R was compared with plain ones and looked
-- dear, an A2-limited bike with full-power ones and looked cheap. Each
-- version's price difference is now learnt per model from the live ads
-- (statistics, no AI) and each comparable is brought to the listing's
-- version before the median.
--
-- How a premium is learnt (model_version_premiums): every live,
-- non-duplicate ad of 300 EUR or more with a year and a mileage, its log
-- price brought to one year and mileage with the model's own depreciation
-- rates (model_depreciation). The premium is the median of the ads with the
-- version less the median of those without it within the years the
-- version's ads span (so a newer generation's price isn't credited to the
-- version), from 5 ads of each, shrunk towards none by n / (n + 5) and
-- limited to +-25 %. Below 5 ads of either it changes nothing.
--
-- Where it counts: listing_fair_prices (so the Deal Score's price slice,
-- the risk's price signal, the market position and the offer), the
-- valuation of a bike of one's own (bike_value_in_years: the plain
-- version's value) and the typed ad's score (typed_ad_score: the versions
-- its text names). The breakdown's version_premiums says which versions
-- moved the estimate and by how much. Market behaviour, exit prices and
-- gone deals stay as they were. The E-Clutch's +1 equipment point stays: it
-- only breaks ties.

-- 1. The versions a listing is, from its stored extras and signals.
create function public.listing_is_e_clutch(p_extras text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce('e_clutch' = any(p_extras), false);
$$;

create function public.listing_is_a2_limited(p_signals text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce('a2_limited' = any(p_signals), false);
$$;

revoke all on function public.listing_is_e_clutch(text[]) from public, anon, authenticated;
revoke all on function public.listing_is_a2_limited(text[]) from public, anon, authenticated;
grant execute on function public.listing_is_e_clutch(text[]) to anon, authenticated;
grant execute on function public.listing_is_a2_limited(text[]) to anon, authenticated;

-- 2. Each model's learnt price difference per version (log of the ratio).
create view public.model_version_premiums
with (security_invoker = true) as
with sample as (
  select l.motorcycle_id, l.year,
         ln(l.price::double precision)
           - d.per_year::double precision * l.year
           + d.per_1000km::double precision * l.mileage / 1000.0 as r,
         public.listing_is_e_clutch(
           coalesce(l.text_extras, public.listing_extras(l.variant, l.description)))
           as e_clutch,
         public.listing_is_a2_limited(
           coalesce(l.text_signals, public.description_signals(l.variant, l.description)))
           as a2_limited
  from public.listings l
  join public.model_depreciation d on d.motorcycle_id = l.motorcycle_id
  where l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.price >= 300
    and l.year is not null
    and l.mileage is not null
),
flagged as (
  select s.motorcycle_id, s.year, s.r, v.version,
         case v.version when 'e_clutch' then s.e_clutch else s.a2_limited end as has
  from sample s
  cross join (values ('e_clutch'), ('a2_limited')) v(version)
),
with_version as (
  select f.motorcycle_id, f.version,
         min(f.year) as from_year, max(f.year) as to_year,
         count(*) as with_count,
         percentile_cont(0.5) within group (order by f.r) as with_median
  from flagged f
  where f.has
  group by f.motorcycle_id, f.version
),
without_version as (
  select w.motorcycle_id, w.version,
         count(*) as without_count,
         percentile_cont(0.5) within group (order by f.r) as without_median
  from with_version w
  join flagged f
    on f.motorcycle_id = w.motorcycle_id
   and f.version = w.version
   and not f.has
   and f.year between w.from_year and w.to_year
  group by w.motorcycle_id, w.version
)
select w.motorcycle_id, w.version,
       w.with_count::integer as with_count,
       o.without_count::integer as without_count,
       round(greatest(-0.25, least(0.25,
         (w.with_median - o.without_median) * w.with_count / (w.with_count + 5.0)
       ))::numeric, 4) as premium
from with_version w
join without_version o using (motorcycle_id, version)
where w.with_count >= 5
  and o.without_count >= 5;

grant select on public.model_version_premiums to anon, authenticated;

-- The breakdown's note: the listing's own versions that moved its estimate,
-- each with the difference in % and how many ads taught it.
create function public.version_premium_notes(
  p_e_clutch boolean, p_e_clutch_premium numeric, p_e_clutch_ads integer,
  p_a2_limited boolean, p_a2_limited_premium numeric, p_a2_limited_ads integer
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select nullif(to_jsonb(array_remove(array[
    case when p_e_clutch and coalesce(p_e_clutch_premium, 0) <> 0
         then jsonb_build_object(
           'version', 'e_clutch',
           'pct', round((exp(p_e_clutch_premium) - 1) * 100, 1),
           'ads', p_e_clutch_ads)
    end,
    case when p_a2_limited and coalesce(p_a2_limited_premium, 0) <> 0
         then jsonb_build_object(
           'version', 'a2_limited',
           'pct', round((exp(p_a2_limited_premium) - 1) * 100, 1),
           'ads', p_a2_limited_ads)
    end
  ]::jsonb[], null)), '[]'::jsonb);
$$;

revoke all on function public.version_premium_notes(boolean, numeric, integer,
  boolean, numeric, integer) from public, anon, authenticated;
grant execute on function public.version_premium_notes(boolean, numeric, integer,
  boolean, numeric, integer) to anon, authenticated;

-- 3. Fair prices: each comparable brought to the listing's version. With no
-- premium learnt the factor is 1 and every figure is what it was.
create or replace view public.listing_fair_prices
with (security_invoker = true) as
with live as (
  select l.id, l.motorcycle_id, l.year, l.mileage, l.price,
         public.model_generation(m.generation_years, l.year::integer) as generation,
         public.listing_is_e_clutch(
           coalesce(l.text_extras, public.listing_extras(l.variant, l.description)))::integer
           as e_clutch,
         public.listing_is_a2_limited(
           coalesce(l.text_signals, public.description_signals(l.variant, l.description)))::integer
           as a2_limited
  from public.listings l
  join public.motorcycles m on m.id = l.motorcycle_id
  where l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.price >= 300
),
models as (
  select c.motorcycle_id,
         array_agg(c.id order by c.id)         as ids,
         array_agg(c.year order by c.id)       as years,
         array_agg(c.mileage order by c.id)    as kms,
         array_agg(c.price order by c.id)      as prices,
         array_agg(c.generation order by c.id) as generations,
         array_agg(c.e_clutch order by c.id)   as e_clutches,
         array_agg(c.a2_limited order by c.id) as a2_limiteds
  from live c
  group by c.motorcycle_id
),
premiums as (
  select p.motorcycle_id,
         coalesce(max(p.premium) filter (where p.version = 'e_clutch'), 0) as e_clutch,
         max(p.with_count) filter (where p.version = 'e_clutch') as e_clutch_ads,
         coalesce(max(p.premium) filter (where p.version = 'a2_limited'), 0) as a2_limited,
         max(p.with_count) filter (where p.version = 'a2_limited') as a2_limited_ads
  from public.model_version_premiums p
  group by p.motorcycle_id
)
select l.id as listing_id, f.comparable_count, f.fair_price,
       case when l.e_clutch + l.a2_limited > 0 and pr.motorcycle_id is not null
            then public.version_premium_notes(
                   l.e_clutch = 1, pr.e_clutch, pr.e_clutch_ads,
                   l.a2_limited = 1, pr.a2_limited, pr.a2_limited_ads)
       end as version_premiums
from live l
join models a on a.motorcycle_id = l.motorcycle_id
join public.model_depreciation d on d.motorcycle_id = l.motorcycle_id
left join premiums pr on pr.motorcycle_id = l.motorcycle_id
-- Comparables without year or mileage are left out when the listing has
-- them; the same generation within 3 years when 5+, else within 3 years
-- when 5+, else all.
cross join lateral (
  select count(*) filter (where abs(l.year - c.year) <= 3
                            and l.generation = c.generation) >= 5 as use_generation,
         count(*) filter (where abs(l.year - c.year) <= 3) >= 5 as use_near
  from unnest(a.ids, a.years, a.kms, a.generations) as c(id, year, mileage, generation)
  where c.id <> l.id
    and (l.year is null or c.year is not null)
    and (l.mileage is null or c.mileage is not null)
) ch
cross join lateral (
  select count(*) as comparable_count,
         round(percentile_cont(0.5) within group (
           order by c.price::double precision
                    * greatest(0.35, least(2.5, exp((
                        d.per_year * coalesce(l.year - c.year, 0)
                        - d.per_1000km * coalesce(l.mileage - c.mileage, 0) / 1000.0
                      )::double precision)))
                    -- The comparable at the listing's version.
                    * exp((
                        coalesce(pr.e_clutch, 0) * (l.e_clutch - c.e_clutch)
                        + coalesce(pr.a2_limited, 0) * (l.a2_limited - c.a2_limited)
                      )::double precision)
         )::numeric, 2) as fair_price
  from unnest(a.ids, a.years, a.kms, a.prices, a.generations,
              a.e_clutches, a.a2_limiteds)
         as c(id, year, mileage, price, generation, e_clutch, a2_limited)
  where c.id <> l.id
    and (l.year is null or c.year is not null)
    and (l.mileage is null or c.mileage is not null)
    and case when ch.use_generation
               then abs(l.year - c.year) <= 3 and l.generation = c.generation
             when ch.use_near then abs(l.year - c.year) <= 3
             else true
        end
) f
where f.comparable_count > 0;

-- 4. A bike of one's own: the plain version's value (each comparable taken
-- back to the plain version), so a typed ad can add its own.
create or replace function public.bike_value_in_years(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer,
  p_from_year integer,
  p_to_year integer
)
returns table(comparable_count integer, fair_price numeric,
              low_price numeric, high_price numeric)
language sql
stable
set search_path = ''
as $$
  with generations as (
    select m.generation_years as years
    from public.motorcycles m where m.id = p_motorcycle_id
  ),
  premiums as (
    select coalesce(max(p.premium) filter (where p.version = 'e_clutch'), 0) as e_clutch,
           coalesce(max(p.premium) filter (where p.version = 'a2_limited'), 0) as a2_limited
    from public.model_version_premiums p
    where p.motorcycle_id = p_motorcycle_id
  ),
  comparables as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near,
           p_year is not null and abs(p_year - c.year) <= 3
             and public.model_generation(g.years, c.year)
                 = public.model_generation(g.years, p_year) as same_generation,
           public.listing_is_e_clutch(
             coalesce(c.text_extras, public.listing_extras(c.variant, c.description)))
             as e_clutch,
           public.listing_is_a2_limited(
             coalesce(c.text_signals, public.description_signals(c.variant, c.description)))
             as a2_limited
    from public.listings c
    cross join generations g
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('active', 'price_changed')
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
      and (p_from_year is null or c.year >= p_from_year)
      and (p_to_year is null or c.year <= p_to_year)
  ),
  chosen as (
    select c.*
    from comparables c
    where case
      when p_from_year is not null or p_to_year is not null then true
      when (select count(*) from comparables n where n.same_generation) >= 5
        then c.same_generation
      when (select count(*) from comparables n where n.near) >= 5 then c.near
      else true
    end
  ),
  adjusted as (
    select ch.price * public.age_mileage_factor(
             p_year - ch.year,
             p_mileage - ch.mileage,
             coalesce(d.per_year, 0.04),
             coalesce(d.per_1000km, 0.002)
           )
           / exp(pr.e_clutch * ch.e_clutch::integer
                 + pr.a2_limited * ch.a2_limited::integer) as price
    from chosen ch
    cross join premiums pr
    left join public.model_depreciation d on d.motorcycle_id = p_motorcycle_id
  )
  select
    count(*)::integer,
    round((percentile_cont(0.5)  within group (order by price))::numeric, 2),
    round((percentile_cont(0.25) within group (order by price))::numeric, 2),
    round((percentile_cont(0.75) within group (order by price))::numeric, 2)
  from adjusted;
$$;

-- 5. A typed ad: the plain value brought to the versions its text names.
create or replace function public.typed_ad_score(
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
  p_variant text default null,
  p_origin text default null
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
  typed as (
    select
      md.*,
      nullif(btrim(coalesce(p_description, '')), '') as description,
      public.listing_extras(nullif(btrim(coalesce(p_variant, '')), ''), p_description) as extras,
      (select coalesce(array_agg(distinct s), '{}'::text[])
       from unnest(
         public.description_signals(nullif(btrim(coalesce(p_variant, '')), ''), p_description)
         || case p_damage
              when 'accident' then array['possible_accident']
              when 'dropped' then array['cosmetic_damage']
              else '{}'::text[]
            end) s) as signals
    from model md
  ),
  premiums as (
    select coalesce(max(p.premium) filter (where p.version = 'e_clutch'), 0) as e_clutch,
           max(p.with_count) filter (where p.version = 'e_clutch') as e_clutch_ads,
           coalesce(max(p.premium) filter (where p.version = 'a2_limited'), 0) as a2_limited,
           max(p.with_count) filter (where p.version = 'a2_limited') as a2_limited_ads
    from public.model_version_premiums p
    where p.motorcycle_id = p_motorcycle_id
  ),
  input as (
    select
      t.*,
      v.comparable_count,
      round(v.fair_price * exp(
        pr.e_clutch * public.listing_is_e_clutch(t.extras)::integer
        + pr.a2_limited * public.listing_is_a2_limited(t.signals)::integer), 2)
        as fair_price,
      public.version_premium_notes(
        public.listing_is_e_clutch(t.extras), pr.e_clutch, pr.e_clutch_ads,
        public.listing_is_a2_limited(t.signals), pr.a2_limited, pr.a2_limited_ads)
        as version_premiums
    from typed t
    cross join premiums pr
    cross join lateral public.bike_value_in_years(t.id, p_year, p_mileage, p_from_year, p_to_year) v
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
      -- The person says it was imported (B.6): the stored ads' sign.
      case when p_origin = 'imported' then 'imported' end,
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
      public.age_score(p_year) as y_score
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
      'version_premiums',     p.version_premiums,
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

-- 6. The run keeps the note in each breakdown (otherwise as in
-- 20261128120000_dealer_score_review.sql).
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql security definer
set search_path = ''
set jit = off
as $function$
declare
  n integer;
begin
  perform public.refresh_new_prices_from_ads();

  with dealer_counts as materialized (
    select d.dealer_key, d.bikes,
           public.dealer_problems(d.relisted, d.sharp_changes,
                                  d.missing_mileage, d.repeated) as problems
    from public.dealer_reliability d
  ),
  dealers as (
    select c.dealer_key, c.bikes,
           public.dealer_score(c.bikes, c.problems, p.rate) as score
    from dealer_counts c
    cross join (
      select sum(problems) / nullif(sum(bikes), 0) as rate
      from dealer_counts
      where bikes >= 5
    ) p
  ),
  fair as materialized (
    select f.listing_id, f.comparable_count, f.fair_price, f.version_premiums
    from public.listing_fair_prices f
  ),
  scored as materialized (
    select
      l.id,
      l.price,
      f.fair_price as market_price,
      f.version_premiums,
      public.damage_allowance(rs.reasons) as allowance,
      -- Not yet legalised in Portugal (N.52): what that costs comes off.
      public.legalisation_cost(
        rs.reasons, coalesce(m.engine_cc_max, m.engine_cc_min),
        case when l.price >= 300 then l.price else f.fair_price end,
        l.year, l.mileage) as legalisation,
      round((f.fair_price - l.price) / f.fair_price * 100, 1) as pct_below_market,
      f.comparable_count as listing_count,
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
    left join fair f on f.listing_id = l.id
    left join lateral public.listing_risk(
      l, case when f.comparable_count >= 3 then f.fair_price end) rs on true
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
        'version_premiums',     s.version_premiums,
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
  ,
  changed as (
    update public.listings l
    set deal_score      = c.deal_score,
        risk_score      = c.risk_score,
        score_breakdown = c.breakdown,
        scored_at       = now()
    from combined c
    where l.id = c.id
      and (l.deal_score, l.risk_score, l.score_breakdown, l.scored_at is null)
          is distinct from (c.deal_score, c.risk_score, c.breakdown, false)
    returning 1
  )
  select count(*) into n from combined;

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
$function$;
