-- Faster scoring runs (performance hunt, PF.1-PF.4; docs/performance-hunt.md).
-- Same results, less work: every function and view below returns what it
-- did before (supabase/tests/faster_runs_test.sql compares them).

-- PF.1 Fair prices. Each listing's comparables come from its model's live
-- ads, packed once per model into arrays, instead of a join of every pair
-- sorted and counted with window functions (17 M rows written to disk at
-- 15 000 live ads). The depreciation factor is age_mileage_factor's
-- formula with the exponential in double precision: numeric exp() was
-- most of the time, and the median was already taken in double precision.
create or replace view public.listing_fair_prices
with (security_invoker = true) as
with live as (
  select l.id, l.motorcycle_id, l.year, l.mileage, l.price,
         public.model_generation(m.generation_years, l.year::integer) as generation
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
         array_agg(c.generation order by c.id) as generations
  from live c
  group by c.motorcycle_id
)
select l.id as listing_id, f.comparable_count, f.fair_price
from live l
join models a on a.motorcycle_id = l.motorcycle_id
join public.model_depreciation d on d.motorcycle_id = l.motorcycle_id
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
         )::numeric, 2) as fair_price
  from unnest(a.ids, a.years, a.kms, a.prices, a.generations)
         as c(id, year, mileage, price, generation)
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

-- PF.2 One listing's Risk Score from its fair price, so the scoring run
-- works fair prices out once (it read them twice: through
-- listing_price_scores and through listing_risk_scores).
create or replace function public.listing_risk(
  p_listing public.listings,
  p_fair_price numeric
)
returns table (risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  select r.risk_score, r.reasons
  from public.risk_from_signals(
    p_listing.price,
    p_fair_price,
    p_listing.year,
    p_listing.mileage,
    p_listing.description,
    p_listing.location,
    p_listing.details_checked_at is not null or p_listing.source = 'olx',
    coalesce(p_listing.seller_type::text = 'private', false),
    p_listing.registrations,
    p_listing.service_book,
    p_listing.origin,
    p_listing.warranty_until,
    (p_listing.relisted_from is not null)::integer
      + coalesce((select (prev.relisted_from is not null)::integer
                  from public.listings prev
                  where prev.id = p_listing.relisted_from), 0),
    p_listing.relisted_since,
    coalesce(p_listing.text_signals,
             public.description_signals(p_listing.variant, p_listing.description))
    || case
         when exists (
           select 1
           from public.listing_photo_matches m
           join public.listings o on o.id = m.other_id
           where m.listing_id = p_listing.id
             and o.first_seen_at < p_listing.first_seen_at
             and (o.motorcycle_id <> p_listing.motorcycle_id
                  or (p_listing.seller_type = 'private' and o.seller_type = 'dealer'))
         )
         then array['photos_reused']
         else '{}'::text[]
       end
    || case
         when p_listing.stock_photos
              and not (p_listing.seller_type = 'dealer' and p_listing.mileage <= 100)
         then array['stock_photos']
         else '{}'::text[]
       end
    || public.fact_edit_signals(p_listing.mileage, p_listing.mileage_from_text,
                                p_listing.mileage_max_seen,
                                p_listing.year, p_listing.year_first_seen)
  ) r
$$;

revoke all on function public.listing_risk(public.listings, numeric)
  from public, anon, authenticated;

create or replace view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.listing_fair_prices f on f.listing_id = l.id
cross join lateral public.listing_risk(
  l, case when f.comparable_count >= 3 then f.fair_price end) r
where l.status in ('active', 'price_changed');

-- PF.2 The scoring run: fair prices once (above), and only the listings
-- whose score changed are written (each run rewrote every live row, 9 runs
-- a day, with its triggers; the age-based slices move once a day). The
-- count returned is still every listing scored. scored_at is now when the
-- score last changed.
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
  fair as materialized (
    select f.listing_id, f.comparable_count, f.fair_price
    from public.listing_fair_prices f
  ),
  scored as materialized (
    select
      l.id,
      l.price,
      f.fair_price as market_price,
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
$$;

revoke all on function public.recalculate_deal_scores()
  from public, anon, authenticated;


-- PF.3 Duplicates. The description's similarity (trigrams of two long
-- texts, the costly part) is worked out once instead of twice, and
-- mark_duplicates skips it for a pair whose other facts are too far apart
-- to reach the threshold even with the text's 30 points (the score of such
-- a pair is never used).
create or replace function public.duplicate_similarity(
  p_mileage_a     integer, p_mileage_b     integer,
  p_price_a       numeric, p_price_b       numeric,
  p_location_a    text,    p_location_b    text,
  p_description_a text,    p_description_b text,
  p_seller_a      text,    p_seller_b      text
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select
    -- mileage
    case
      when p_mileage_a is null or p_mileage_b is null then 0
      when p_mileage_a = p_mileage_b
        then case when p_mileage_a >= 500 then 40 else 10 end
      when abs(p_mileage_a - p_mileage_b) <= 100
           and greatest(p_mileage_a, p_mileage_b) >= 500 then 20
      else 0
    end
    -- price
    + case
      when p_price_a is null or p_price_b is null
           or greatest(p_price_a, p_price_b) <= 0 then 0
      when abs(p_price_a - p_price_b) / greatest(p_price_a, p_price_b) <= 0.03 then 20
      when abs(p_price_a - p_price_b) / greatest(p_price_a, p_price_b) <= 0.10 then 10
      else 0
    end
    -- location
    + case
      when nullif(btrim(p_location_a), '') is not null
           and lower(btrim(p_location_a)) = lower(btrim(p_location_b)) then 20
      else 0
    end
    -- description text, only when both are long enough to compare
    + case
      when char_length(coalesce(p_description_a, '')) < 40
           or char_length(coalesce(p_description_b, '')) < 40 then 0
      else (select case when t.similarity >= 0.8 then 30
                        when t.similarity >= 0.6 then 15
                        else 0
                   end
            from (select extensions.similarity(lower(p_description_a),
                                               lower(p_description_b))
                           as similarity) t)
    end
    -- dealer name
    + case
      when nullif(btrim(p_seller_a), '') is not null
           and lower(btrim(p_seller_a)) = lower(btrim(p_seller_b)) then 10
      else 0
    end
$$;

create or replace function public.mark_duplicates(p_threshold integer default 70)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with recursive live as (
    select * from public.listings
    where status in ('active', 'price_changed')
  ),
  pairs as (
    select
      b.id as dup_id,
      a.id as original_id,
      a.first_seen_at as original_seen,
      case
        when coalesce(abs(a.mileage - b.mileage) <= 1000, true)
         and exists (select 1 from public.listing_photo_matches m
                     where m.listing_id = a.id and m.other_id = b.id)
          then 100
        -- the text adds at most 30: below the threshold whatever it says
        when facts.score + 30 < p_threshold then facts.score
        else public.duplicate_similarity(
          a.mileage, b.mileage, a.price, b.price, a.location, b.location,
          a.description, b.description, a.seller_name, b.seller_name
        )
      end as score
    from live a
    join live b
      on a.motorcycle_id = b.motorcycle_id
     and a.year = b.year
     and (a.first_seen_at, a.id) < (b.first_seen_at, b.id)
    cross join lateral (
      select public.duplicate_similarity(
        a.mileage, b.mileage, a.price, b.price, a.location, b.location,
        null, null, a.seller_name, b.seller_name) as score
    ) facts
    -- a dealer's identical new bikes are separate stock, not duplicates
    where not (a.source = b.source
               and coalesce(a.mileage, 0) < 500
               and coalesce(b.mileage, 0) < 500)
  ),
  best as (
    select distinct on (dup_id) dup_id, original_id, score
    from pairs
    where score >= p_threshold
    order by dup_id, original_seen, original_id
  ),
  -- Chains: if C duplicates B and B duplicates A, C points at A. An
  -- original is always seen before its copy, so a chain never loops.
  chain (dup_id, root_id, score, depth) as (
    select dup_id, original_id, score, 0 from best
    union all
    select c.dup_id, b.original_id, c.score, c.depth + 1
    from chain c
    join best b on b.dup_id = c.root_id
  ),
  resolved as (
    select distinct on (dup_id) dup_id, root_id, score
    from chain
    order by dup_id, depth desc
  ),
  wanted as (
    select l.id, r.root_id, r.score
    from live l
    left join resolved r on r.dup_id = l.id
  ),
  changed as (
    update public.listings l
    set duplicate_of = w.root_id,
        duplicate_score = w.score
    from wanted w
    where l.id = w.id
      and (l.duplicate_of, l.duplicate_score)
          is distinct from (w.root_id, w.score)
    returning 1
  )
  select count(*) into n from best;

  -- A gone listing keeps its mark; one that points at a listing that is
  -- now itself a copy follows it to the first.
  for i in 1..5 loop
    update public.listings c
    set duplicate_of = p.duplicate_of
    from public.listings p
    where c.duplicate_of = p.id and p.duplicate_of is not null;
    exit when not found;
  end loop;

  perform public.mark_relists(p_threshold);

  return n;
end;
$$;

revoke all on function public.mark_duplicates(integer)
  from public, anon, authenticated;
grant execute on function public.mark_duplicates(integer) to service_role;

-- PF.4: the list's per-row computed fields in one function each.
--
-- Ofertas filters on in_my_models and may sort on distance_km. Each was a
-- chain of SQL functions with their own search_path, so none was inlined
-- and every row paid two or three function calls: 1.8 s for 15 000 live
-- ads, 2.4 s with the distance. The same rules written out in one function
-- each take 0.26 s and 1.0 s. caller_tracks, user_tracks, collected,
-- distance_from_home and likes_colour stay for their other callers.

create or replace function public.in_my_models(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
    then exists (select 1 from public.motorcycles m
                 where m.id = l.motorcycle_id
                   and m.is_active
                   and (l.year is null or l.year >= m.min_year))
    else exists (select 1 from public.user_models u
                 where u.user_id = auth.uid()
                   and u.motorcycle_id = l.motorcycle_id
                   and u.tracked
                   and (l.year is null or l.year >= u.min_year)
                   and (l.year is null or u.max_year is null
                        or l.year <= u.max_year))
  end
$$;

create or replace function public.distance_km(l public.listings)
returns integer
language sql
stable
set search_path = ''
as $$
  select public.distance_between(hp.lat, hp.lon, p.lat, p.lon)
  from public.user_home h
  join public.places hp on hp.key = h.place_key
  join public.places p on p.key = public.place_key(l.location)
  where h.user_id = auth.uid()
$$;

create or replace function public.my_colour(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.user_models u
                 where u.user_id = auth.uid()
                   and u.motorcycle_id = l.motorcycle_id
                   and l.colour = any (u.colours))
$$;
