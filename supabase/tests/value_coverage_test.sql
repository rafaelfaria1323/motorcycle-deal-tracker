-- N.106 (20261115120000_value_coverage.sql): a valuation is ready once
-- 5+ ads within 3 years are stored, whatever the collected years; a
-- model named another way finds the catalog's; comparables of the same
-- generation come first.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false);
insert into public.collector_runs (started_at, status)
values (now() - interval '1 hour', 'ok');
update public.motorcycles
set collected_since = now() - interval '2 days', min_year = 2024, is_active = true
where slug = 'yamaha-mt-07';

-- Generations.
do $$
begin
  assert public.model_generation('{2014,2018,2021,2025}', 2026) = 2025, '2026 is the 2025 one';
  assert public.model_generation('{2014,2018,2021,2025}', 2021) = 2021, 'a first year is its own';
  assert public.model_generation('{2014,2018,2021,2025}', 2012) is null, 'before the first';
  assert public.model_generation('{}', 2020) is null, 'unknown generations';
  assert public.model_generation('{2014}', null) is null, 'unknown year';
  assert (select generation_years from public.motorcycles where slug = 'yamaha-mt-07')
         = '{2014,2018,2021,2025}', 'the MT-07''s generations are seeded';
  assert has_function_privilege('anon', 'public.model_generation(smallint[], integer)', 'execute'),
    'the invoker view can call it for visitors';
  assert not has_function_privilege('anon', 'public.near_comparable_count(uuid, integer)', 'execute')
     and not has_function_privilege('authenticated', 'public.name_key(text)', 'execute'),
    'the helpers are internal';
end $$;

-- Readiness: followed from 2024 only, a 2026 bike waits without ads ...
do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
begin
  assert not public.bike_value_ready(v_mt07, 2026), 'no ads, years not reached: waits';
  assert public.bike_value_ready(v_mt07, 2027), '2024 reaches 2027 minus 3';
end $$;

-- ... and is ready once 5 ads within 3 years are stored: 2025 and 2026
-- (the new generation) at 9 000 €, 2024 (the one before) at 7 000 €.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'vc' || g, 'https://x/vc' || g, m.id, m.brand, m.model,
       case when g <= 5 then 2025 + g % 2 else 2024 end, 1000,
       case when g <= 5 then 9000 else 7000 end
from public.motorcycles m, generate_series(1, 8) g
where m.slug = 'yamaha-mt-07';

do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v record;
  f record;
begin
  assert public.near_comparable_count(v_mt07, 2026) = 8, 'eight within 3 years';
  assert public.bike_value_ready(v_mt07, 2026), '5+ near ads: ready';
  update public.motorcycles set is_active = false where id = v_mt07;
  assert not public.bike_value_ready(v_mt07, 2026), 'not collected: waits';
  update public.motorcycles set is_active = true where id = v_mt07;

  -- 5 of the same generation: the 2024 ads are left out.
  select * into v from public.bike_value(v_mt07, 2026, 1000);
  assert v.comparable_count = 5, format('five of the generation, got %s', v.comparable_count);
  assert v.fair_price = 9000, format('the new generation''s price, got %s', v.fair_price);

  -- The same in a stored ad's fair price (the other four of its generation
  -- are too few: the 3 earlier ones count again).
  select f2.* into f
  from public.listing_fair_prices f2
  join public.listings l on l.id = f2.listing_id
  where l.source_listing_id = 'vc1';
  assert f.comparable_count = 7, format('four of its generation are too few, got %s', f.comparable_count);

  -- Unknown generations: within 3 years, as before.
  update public.motorcycles set generation_years = '{}' where id = v_mt07;
  select * into v from public.bike_value(v_mt07, 2026, 1000);
  assert v.comparable_count = 8, format('all eight near ones, got %s', v.comparable_count);
  update public.motorcycles set generation_years = '{2014,2018,2021,2025}' where id = v_mt07;
end $$;

-- A sixth ad of the generation: a stored ad of it now uses only its own.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'vc9', 'https://x/vc9', m.id, m.brand, m.model, 2026, 1000, 9000
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  f record;
begin
  select f2.* into f
  from public.listing_fair_prices f2
  join public.listings l on l.id = f2.listing_id
  where l.source_listing_id = 'vc1';
  assert f.comparable_count = 5 and f.fair_price = 9000,
    format('the five others of its generation, got %s at %s', f.comparable_count, f.fair_price);
end $$;

-- The answer to a waiting request comes once the ads are there.
insert into public.bike_value_requests (user_id, motorcycle_id, year, mileage, waited, requested_at)
select '00000000-0000-0000-0000-0000000000a1', id, 2026, 46, true, now() - interval '2 hours'
from public.motorcycles where slug = 'yamaha-mt-07';
update public.motorcycles set min_year = 2024 where slug = 'yamaha-mt-07';
update public.listings set last_seen_at = now() where source_listing_id = 'vc1';

do $$
declare
  r record;
begin
  select * into r from public.answer_bike_value_requests(now() - interval '1 hour');
  assert r.year = 2026 and r.comparable_count = 6 and r.fair_price > 9000,
    format('answered from the 2025-2026 ads (46 km: a little more): %s at %s', r.comparable_count, r.fair_price);
end $$;

-- Names: spelled another way, or an alias, finds the catalog's model.
update public.motorcycles set aliases = '{YZF-R7}' where slug = 'yamaha-r7';
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';

do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v_count integer := (select count(*) from public.motorcycles);
begin
  assert public.bike_value_model('Yamaha', 'MT07') = v_mt07, 'MT07';
  assert public.bike_value_model('YAMAHA', 'mt 07') = v_mt07, 'mt 07';
  assert public.bike_value_model('Yamaha', 'MT-07') = v_mt07, 'its own name';
  assert public.bike_value_model('Yamaha', 'yzf r7')
         = (select id from public.motorcycles where slug = 'yamaha-r7'), 'an alias';
  assert (select count(*) from public.motorcycles) = v_count, 'nothing added';
  assert public.bike_value_model('Honda', 'CB650R') <> v_mt07, 'another model stays apart';
end $$;
