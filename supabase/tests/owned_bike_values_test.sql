-- "A minha mota" over time (20261113170000_owned_bike_values.sql): one
-- value per bike and Lisbon month, at its mileage that day, only with
-- enough comparables and only for real accounts; owner-only reads.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', false),
  ('00000000-0000-0000-0000-0000000000e2', false),
  ('00000000-0000-0000-0000-0000000000e3', true);
insert into public.ownership_settings (user_id, km_per_year)
values ('00000000-0000-0000-0000-0000000000e1', 6000);

-- Five live MT-07 ads; no R7 ads.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'obv' || g, 'https://x/obv' || g, m.id, m.brand, m.model,
       2020, 20000, 6000 + g * 100
from public.motorcycles m, generate_series(1, 5) g
where m.slug = 'yamaha-mt-07';

insert into public.owned_bikes (id, user_id, motorcycle_id, year, price_paid,
                                mileage_at_purchase, bought_on)
select v.id::uuid, v.owner::uuid, m.id, v.year, 6500, v.km, v.bought::date
from (values
  ('00000000-0000-0000-0000-00000000b0e1', '00000000-0000-0000-0000-0000000000e1',
   'yamaha-mt-07', 2020, 18000, '2026-05-01'),
  ('00000000-0000-0000-0000-00000000b0e2', '00000000-0000-0000-0000-0000000000e1',
   'yamaha-r7', 2022, null, '2026-05-01'),
  ('00000000-0000-0000-0000-00000000b0e3', '00000000-0000-0000-0000-0000000000e2',
   'yamaha-mt-07', 2020, null, '2026-11-20'),
  ('00000000-0000-0000-0000-00000000b0e4', '00000000-0000-0000-0000-0000000000e3',
   'yamaha-mt-07', 2020, 10000, '2026-01-01')
) v(id, owner, slug, year, km, bought)
join public.motorcycles m on m.slug = v.slug;

-- October's value, as last month's run kept it.
insert into public.owned_bike_values (bike_id, month, value, mileage, comparables)
values ('00000000-0000-0000-0000-00000000b0e1', '2026-10-01', 6400, 21000, 5);

do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  r record;
  v_count integer;
begin
  -- The mileage as the app's mileageNow: purchase km plus km a year, to 100.
  assert public.owned_bike_mileage(10000, '2026-01-01', 5000, '2027-01-01') = 15000,
    'a year at 5 000 km';
  assert public.owned_bike_mileage(10000, '2026-01-01', 5000, '2026-01-01') = 10000,
    'the day it was bought';
  assert public.owned_bike_mileage(null, '2026-01-01', 5000, '2027-01-01') is null,
    'unknown purchase km';

  -- A Monday in November, 09:00 Lisbon.
  select count(*) into v_count
  from public.record_owned_bike_values('2026-11-02 09:00+00');
  assert v_count = 1, format('only the MT-07 bought in May is valued, got %s', v_count);

  select * into r from public.owned_bike_values
  where bike_id = '00000000-0000-0000-0000-00000000b0e1' and month = '2026-11-01';
  assert r.mileage = public.owned_bike_mileage(18000, '2026-05-01', 6000, '2026-11-02'),
    'at the owner''s km a year';
  assert r.value = (select fair_price from public.bike_value(v_mt07, 2020, r.mileage)),
    'bike_value at that mileage';
  assert r.comparables = 5 and r.recorded_at = '2026-11-02 09:00+00';

  assert not exists (select 1 from public.owned_bike_values
                     where bike_id = '00000000-0000-0000-0000-00000000b0e2'),
    'no value without 3 comparables';
  assert not exists (select 1 from public.owned_bike_values
                     where bike_id = '00000000-0000-0000-0000-00000000b0e3'),
    'not before it was bought';
  assert not exists (select 1 from public.owned_bike_values
                     where bike_id = '00000000-0000-0000-0000-00000000b0e4'),
    'anonymous sessions keep no bikes';

  -- The same month again: nothing more.
  assert not exists (select 1 from public.record_owned_bike_values('2026-11-09 09:00+00')),
    'one value a month';

  -- December: the row carries November's value as the previous one.
  select * into r from public.record_owned_bike_values('2026-12-07 09:00+00')
  where bike_id = '00000000-0000-0000-0000-00000000b0e1';
  assert r.user_id = '00000000-0000-0000-0000-0000000000e1'
     and r.brand = 'Yamaha' and r.model = 'MT-07' and r.year = 2020;
  assert r.previous_month = '2026-11-01'
     and r.previous_value = (select value from public.owned_bike_values
                             where bike_id = r.bike_id and month = '2026-11-01'),
    'the latest earlier month';
  -- Bought 20 November: its first value is December's, with none before.
  assert exists (select 1 from public.owned_bike_values
                 where bike_id = '00000000-0000-0000-0000-00000000b0e3'
                   and month = '2026-12-01' and mileage is null);

  -- 30 November 23:30 UTC is already December in Lisbon only in summer;
  -- in winter Lisbon is UTC, so this is still November.
  assert date_trunc('month', ('2026-11-30 23:30+00'::timestamptz
                              at time zone 'Europe/Lisbon'))::date = '2026-11-01';
end $$;

-- Owners read their own bikes' values; no one writes them.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000e1';
do $$
begin
  assert (select count(*) from public.owned_bike_values) = 3,
    'October, November and December of the MT-07';
  begin
    insert into public.owned_bike_values (bike_id, month, value, comparables)
    values ('00000000-0000-0000-0000-00000000b0e1', '2027-01-01', 1, 5);
    assert false, 'an owner wrote a value';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.record_owned_bike_values(now());
    assert false, 'the app recorded values';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000e2';
do $$
begin
  assert (select count(*) from public.owned_bike_values) = 1,
    'another account sees only its own bike';
end $$;

set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  assert (select count(*) from public.owned_bike_values) = 0, 'anonymous: none';
end $$;
reset role;

-- A bike deleted takes its values.
delete from public.owned_bikes where id = '00000000-0000-0000-0000-00000000b0e1';
do $$
begin
  assert not exists (select 1 from public.owned_bike_values
                     where bike_id = '00000000-0000-0000-0000-00000000b0e1');
end $$;
