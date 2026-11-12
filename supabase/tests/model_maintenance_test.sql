-- Each model's maintenance figures (N.60): filled for the catalog,
-- readable by app users, and checked on the way in.

do $$
declare
  r record;
begin
  select front_tyre, rear_tyre, cylinders, service_interval_km, valve_check_km
  into r from public.motorcycles where slug = 'yamaha-mt-07';
  assert r.front_tyre = '120/70-17', 'MT-07 front tyre';
  assert r.rear_tyre = '180/55-17', 'MT-07 rear tyre';
  assert r.cylinders = 2, 'MT-07 is a twin';
  assert r.service_interval_km = 10000, 'Yamaha services every 10 000 km';
  assert r.valve_check_km = 40000, 'MT-07 valves every 40 000 km';

  select cylinders, rear_tyre into r from public.motorcycles where slug = 'honda-cb650r';
  assert r.cylinders = 4 and r.rear_tyre = '180/55-17', 'CB650R';

  assert (select valve_check_km from public.motorcycles where slug = 'honda-cb125r') is null,
    'unknown stays null';
  assert not exists (
    select 1 from public.motorcycles
    where slug in ('yamaha-mt-07', 'yamaha-r7', 'yamaha-tracer-7', 'yamaha-r1',
                   'yamaha-r3', 'yamaha-r9', 'honda-cb125r', 'honda-cb300r',
                   'honda-cbr500r', 'honda-cb750-hornet', 'honda-cb650r',
                   'honda-cbr650r', 'honda-cbr600rr')
      and (front_tyre is null or rear_tyre is null or cylinders is null
           or service_interval_km is null)
  ), 'every catalog model has its tyres, cylinders and service interval';
end $$;

-- A bad tyre size or interval is refused.
do $$
begin
  begin
    update public.motorcycles set rear_tyre = '180-55-17' where slug = 'yamaha-r7';
    assert false, 'a malformed tyre size was accepted';
  exception when check_violation then null;
  end;
  begin
    update public.motorcycles set cylinders = 0 where slug = 'yamaha-r7';
    assert false, 'zero cylinders were accepted';
  exception when check_violation then null;
  end;
  begin
    update public.motorcycles set service_interval_km = 500 where slug = 'yamaha-r7';
    assert false, 'a 500 km service interval was accepted';
  exception when check_violation then null;
  end;
end $$;

-- The app reads them with the catalog.
set local role authenticated;
do $$
begin
  assert (select cylinders from public.motorcycles where slug = 'yamaha-r9') = 3,
    'app users read the maintenance figures';
end $$;
reset role;
