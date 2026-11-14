-- N.106: "Avaliar um anúncio" kept a 2026 MT-07 waiting for a collection
-- although dozens of its ads were stored. Three changes:
--
-- 1. A valuation is ready when the model is collected and either its
--    collected years reach the bike's year minus 3 (as before) or 5+ of
--    its live ads are already within 3 years of the bike: bike_value
--    then uses only those, so older years would change nothing.
-- 2. A model typed or picked by name ("MT07", "Mt 07") finds the
--    catalog's model by its letters and digits or by an alias, not only
--    by the exact name, so it doesn't become a new, empty model.
-- 3. Generations: motorcycles.generation_years (the first model year of
--    each generation; empty when unknown). Comparables of the same
--    generation come first: a fair price, a bike's value and an exit
--    price use only the same generation's ads within 3 years when there
--    are 5+ of them, else (as before) the ads within 3 years, else all.

-- 1. Coverage --------------------------------------------------------------

-- Live ads of a model within 3 years of a year, as bike_value counts them.
create or replace function public.near_comparable_count(p_motorcycle_id uuid, p_year integer)
returns integer
language sql stable
set search_path = ''
as $$
  select count(*)::integer
  from public.listings c
  where c.motorcycle_id = p_motorcycle_id
    and c.status in ('active', 'price_changed')
    and c.duplicate_of is null
    and c.price >= 300
    and abs(p_year - c.year) <= 3
$$;
revoke all on function public.near_comparable_count(uuid, integer)
  from public, anon, authenticated;

create or replace function public.bike_value_ready(p_motorcycle_id uuid, p_year integer)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.motorcycles m
    where m.id = p_motorcycle_id
      and m.is_active
      and (m.min_year <= greatest(p_year - 3, 1990)
           or public.near_comparable_count(m.id, p_year) >= 5)
      and exists (select 1 from public.collector_runs r
                  where r.started_at >= m.collected_since
                    and r.status in ('ok', 'partial'))
  )
$$;
revoke all on function public.bike_value_ready(uuid, integer)
  from public, anon, authenticated;

create or replace function public.answer_bike_value_requests(p_started_at timestamp with time zone)
returns table(id uuid, user_id uuid, brand text, model text, year integer, mileage integer,
              comparable_count integer, fair_price numeric, is_ad boolean, listing_id uuid,
              deal_score smallint, risk_score smallint)
language plpgsql security definer
set search_path = ''
as $$
begin
  return query
  with answered as (
    update public.bike_value_requests r
    set answered_at = now()
    from public.motorcycles m
    where r.answered_at is null
      and m.id = r.motorcycle_id
      and m.is_active
      and m.collected_since <= p_started_at
      and (m.min_year <= greatest(r.year - 3, 1990)
           or public.near_comparable_count(m.id, r.year) >= 5)
      and (r.requested_at < now() - interval '1 day'
           or (r.ad_url is null
               and exists (select 1 from public.listings l
                           where l.motorcycle_id = m.id
                             and l.last_seen_at >= p_started_at))
           or (r.ad_url is not null
               and exists (select 1 from public.listings l
                           where l.id = public.listing_for_ad(r.ad_url)
                             and l.last_seen_at >= p_started_at)))
    returning r.id, r.user_id, r.motorcycle_id, r.year, r.mileage, r.ad_url
  )
  select a.id, a.user_id, m.brand, m.model, a.year, a.mileage,
         v.comparable_count, v.fair_price,
         a.ad_url is not null, l.id, l.deal_score, l.risk_score
  from answered a
  join public.motorcycles m on m.id = a.motorcycle_id
  cross join lateral public.bike_value(a.motorcycle_id, a.year, a.mileage) v
  left join public.listings l
    on a.ad_url is not null and l.id = public.listing_for_ad(a.ad_url)
  order by a.id;
end;
$$;
revoke all on function public.answer_bike_value_requests(timestamp with time zone)
  from public, anon, authenticated;

-- 2. Names -----------------------------------------------------------------

-- Only the letters and digits, lower case: "MT-07", "MT 07" and "mt07"
-- are the same name.
create or replace function public.name_key(p_name text)
returns text
language sql immutable
set search_path = ''
as $$
  select regexp_replace(lower(normalize(coalesce(p_name, ''), NFC)), '[^[:alnum:]]+', '', 'g')
$$;
revoke all on function public.name_key(text) from public, anon, authenticated;

create or replace function public.bike_value_model(
  p_brand text, p_model text, p_olx_search text default null,
  p_standvirtual_search text default null, p_engine_cc_min integer default null,
  p_engine_cc_max integer default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_brand text := normalize(btrim(p_brand), NFC);
  v_model text := normalize(btrim(p_model), NFC);
  v_slug text;
  v_id uuid;
  v_range int4range := public.engine_range_from_name(v_model);
begin
  perform public.require_account();

  if nullif(v_brand, '') is null or nullif(v_model, '') is null then
    raise exception 'Brand and model are required' using errcode = '22023';
  end if;
  if p_engine_cc_min not between 1 and 3000
     or p_engine_cc_max not between 1 and 3000
     or p_engine_cc_min > p_engine_cc_max then
    raise exception 'Engine size range %-% is invalid',
      p_engine_cc_min, p_engine_cc_max using errcode = '22023';
  end if;

  v_slug := btrim(regexp_replace(lower(v_brand || '-' || v_model),
                                 '[^a-z0-9]+', '-', 'g'), '-');

  -- The same brand and the same name or an alias, by letters and digits.
  select m.id into v_id
  from public.motorcycles m
  where m.slug = v_slug
     or (public.name_key(m.brand) = public.name_key(v_brand)
         and (public.name_key(m.model) = public.name_key(v_model)
              or exists (select 1 from unnest(m.aliases) a
                         where public.name_key(a) = public.name_key(v_model))))
  order by m.is_active desc,
           (public.name_key(m.model) = public.name_key(v_model)) desc,
           m.created_at
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  if p_engine_cc_min is null and p_engine_cc_max is null then
    p_engine_cc_min := lower(v_range);
    p_engine_cc_max := upper(v_range) - 1;
  end if;

  insert into public.motorcycles
    (brand, model, slug, min_year, is_active, collected_since,
     olx_search, standvirtual_search, engine_cc_min, engine_cc_max)
  values
    (v_brand, v_model, v_slug, extract(year from now())::integer, false, null,
     nullif(btrim(p_olx_search), ''),
     nullif(btrim(p_standvirtual_search), ''),
     p_engine_cc_min, p_engine_cc_max)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.bike_value_model(text, text, text, text, integer, integer)
  from public, anon;
grant execute on function public.bike_value_model(text, text, text, text, integer, integer)
  to authenticated;

-- 3. Generations -----------------------------------------------------------

alter table public.motorcycles
  add column generation_years smallint[] not null default '{}';

-- The generation a year belongs to: the latest first year at or before
-- it; null when the year or the generations are unknown.
create or replace function public.model_generation(p_generation_years smallint[], p_year integer)
returns integer
language sql immutable
set search_path = ''
as $$
  select max(g)::integer from unnest(p_generation_years) g where g <= p_year
$$;
revoke all on function public.model_generation(smallint[], integer) from public;
grant execute on function public.model_generation(smallint[], integer)
  to anon, authenticated, service_role;

-- The makers' generations (the first model year of each; a facelift that
-- changed the engine, frame or electronics counts as one).
update public.motorcycles m
set generation_years = v.years
from (values
  ('yamaha-mt-07',       '{2014,2018,2021,2025}'::smallint[]),
  ('yamaha-r7',          '{2022}'::smallint[]),
  ('yamaha-tracer-7',    '{2016,2020}'::smallint[]),
  ('yamaha-r1',          '{2015,2020}'::smallint[]),
  ('yamaha-r3',          '{2015,2019}'::smallint[]),
  ('yamaha-r9',          '{2025}'::smallint[]),
  ('honda-cb650r',       '{2019,2021,2024}'::smallint[]),
  ('honda-cbr650r',      '{2019,2021,2024}'::smallint[]),
  ('honda-cb125r',       '{2018,2021}'::smallint[]),
  ('honda-cb300r',       '{2018,2022}'::smallint[]),
  ('honda-cbr500r',      '{2013,2016,2019,2022,2024}'::smallint[]),
  ('honda-cb750-hornet', '{2023,2025}'::smallint[]),
  ('honda-cbr600rr',     '{2007,2013,2024}'::smallint[])
) v(slug, years)
where m.slug = v.slug;

create or replace view public.listing_fair_prices
with (security_invoker = true) as
with live as (
  select l.id, l.motorcycle_id, l.year, l.mileage, l.price,
         public.model_generation(m.generation_years, l.year) as generation
  from public.listings l
  join public.motorcycles m on m.id = l.motorcycle_id
  where l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.price >= 300
),
pairs as (
  select l.id, l.year as l_year, l.mileage as l_mileage, l.motorcycle_id,
         c.id as c_id, c.year as c_year, c.mileage as c_mileage, c.price as c_price,
         abs(l.year - c.year) <= 3 as near,
         abs(l.year - c.year) <= 3 and l.generation = c.generation as same_generation
  from live l
  join live c
    on  c.motorcycle_id = l.motorcycle_id
    and c.id <> l.id
    -- A comparable without a year or mileage would count as the same age
    -- or mileage as the listing; leave it out when the listing has them.
    and (l.year is null or c.year is not null)
    and (l.mileage is null or c.mileage is not null)
),
chosen as (
  select p.*,
         -- The narrowest set with enough comparables: the same generation
         -- within 3 years, else within 3 years, else all.
         count(*) filter (where p.same_generation) over (partition by p.id) >= 5
           as use_generation,
         count(*) filter (where p.near) over (partition by p.id) >= 5 as use_near
  from pairs p
)
select
  ch.id                as listing_id,
  count(ch.c_id)       as comparable_count,
  round((percentile_cont(0.5) within group (
    order by ch.c_price * public.age_mileage_factor(ch.l_year - ch.c_year,
                                                    ch.l_mileage - ch.c_mileage,
                                                    d.per_year,
                                                    d.per_1000km)
  ))::numeric, 2)      as fair_price
from chosen ch
join public.model_depreciation d on d.motorcycle_id = ch.motorcycle_id
where case when ch.use_generation then ch.same_generation
           when ch.use_near then ch.near
           else true end
group by ch.id;

create or replace function public.bike_value(p_motorcycle_id uuid, p_year integer,
                                             p_mileage integer default null)
returns table(comparable_count integer, fair_price numeric, low_price numeric,
              high_price numeric)
language sql stable
set search_path = ''
as $$
  with generations as (
    select m.generation_years as years
    from public.motorcycles m where m.id = p_motorcycle_id
  ),
  comparables as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near,
           p_year is not null and abs(p_year - c.year) <= 3
             and public.model_generation(g.years, c.year)
                 = public.model_generation(g.years, p_year) as same_generation
    from public.listings c
    cross join generations g
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('active', 'price_changed')
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
  ),
  chosen as (
    select c.*
    from comparables c
    where case
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
           ) as price
    from chosen ch
    left join public.model_depreciation d on d.motorcycle_id = p_motorcycle_id
  )
  select
    count(*)::integer,
    round((percentile_cont(0.5)  within group (order by price))::numeric, 2),
    round((percentile_cont(0.25) within group (order by price))::numeric, 2),
    round((percentile_cont(0.75) within group (order by price))::numeric, 2)
  from adjusted;
$$;

create or replace function public.exit_price(p_motorcycle_id uuid, p_year integer,
                                             p_mileage integer default null,
                                             p_except uuid default null)
returns table(gone_count integer, median_price numeric)
language sql stable
set search_path = ''
as $$
  with excepted as (
    select e.id, e.duplicate_of
    from public.listings e
    where e.id = p_except
  ),
  generations as (
    select m.generation_years as years
    from public.motorcycles m where m.id = p_motorcycle_id
  ),
  gone as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near,
           p_year is not null and abs(p_year - c.year) <= 3
             and public.model_generation(g.years, c.year)
                 = public.model_generation(g.years, p_year) as same_generation
    from public.listings c
    cross join generations g
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('removed', 'sold')
      and c.last_seen_at >= now() - interval '90 days'
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
      and public.exit_kind(c) in ('sold_in_text', 'likely_sold')
      and not exists (
        select 1 from excepted x
        where c.id = x.id or c.id = x.duplicate_of
      )
  ),
  chosen as (
    select g.*
    from gone g
    where case
      when (select count(*) from gone n where n.same_generation) >= 5
        then g.same_generation
      when (select count(*) from gone n where n.near) >= 5 then g.near
      else true
    end
  ),
  adjusted as (
    select ch.price * public.age_mileage_factor(
             p_year - ch.year,
             p_mileage - ch.mileage,
             coalesce(d.per_year, 0.04),
             coalesce(d.per_1000km, 0.002)
           ) as price
    from chosen ch
    left join public.model_depreciation d on d.motorcycle_id = p_motorcycle_id
  )
  select
    count(*)::integer,
    round((percentile_cont(0.5) within group (order by price))::numeric, 2)
  from adjusted;
$$;
