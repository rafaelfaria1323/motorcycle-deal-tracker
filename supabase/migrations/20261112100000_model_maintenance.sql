-- Each model's own maintenance figures (N.60), so the app's cost of
-- ownership prices its tyres, services and valve checks by the bike rather
-- than by its engine size alone: the tyre sizes (the tyre set's price comes
-- from their widths), the cylinders (labour of a service and a valve
-- check), and the maker's European intervals for the oil service and the
-- valve clearance check. Null means unknown: the app falls back to its
-- figures by engine size. Read by everyone with the catalog.
alter table public.motorcycles
  add column front_tyre          text
    constraint motorcycles_front_tyre_size
      check (front_tyre ~ '^[0-9]{2,3}/[0-9]{2}-[0-9]{2}$'),
  add column rear_tyre           text
    constraint motorcycles_rear_tyre_size
      check (rear_tyre ~ '^[0-9]{2,3}/[0-9]{2}-[0-9]{2}$'),
  add column cylinders           smallint
    constraint motorcycles_cylinders check (cylinders between 1 and 6),
  add column service_interval_km integer
    constraint motorcycles_service_interval
      check (service_interval_km between 1000 and 50000),
  add column valve_check_km      integer
    constraint motorcycles_valve_check
      check (valve_check_km between 5000 and 100000);

comment on column public.motorcycles.front_tyre is
  'Front tyre size, e.g. 120/70-17; with rear_tyre prices the tyre set.';
comment on column public.motorcycles.cylinders is
  'Cylinders: the labour of a service and of a valve clearance check.';
comment on column public.motorcycles.service_interval_km is
  'The maker''s oil service interval in Europe, km.';
comment on column public.motorcycles.valve_check_km is
  'The maker''s valve clearance check interval in Europe, km; null unknown.';

-- The catalog's models (owners' manuals and service schedules, 2026):
-- Yamaha services every 10 000 km and checks the valves every 40 000 km;
-- Honda every 12 000 km, the valves every 24 000 km (the 650 fours'
-- every 38 400 km).
update public.motorcycles m
set front_tyre = v.front_tyre,
    rear_tyre = v.rear_tyre,
    cylinders = v.cylinders,
    service_interval_km = v.service_km,
    valve_check_km = v.valve_km
from (values
  ('yamaha-mt-07',       '120/70-17', '180/55-17', 2, 10000, 40000),
  ('yamaha-r7',          '120/70-17', '180/55-17', 2, 10000, 40000),
  ('yamaha-tracer-7',    '120/70-17', '180/55-17', 2, 10000, 40000),
  ('yamaha-r1',          '120/70-17', '190/55-17', 4, 10000, 40000),
  ('yamaha-r3',          '110/70-17', '140/70-17', 2, 10000, 40000),
  ('yamaha-r9',          '120/70-17', '180/55-17', 3, 10000, 40000),
  ('honda-cb125r',       '110/70-17', '150/60-17', 1, 12000, null),
  ('honda-cb300r',       '110/70-17', '150/60-17', 1, 12000, 24000),
  ('honda-cbr500r',      '120/70-17', '160/60-17', 2, 12000, 24000),
  ('honda-cb750-hornet', '120/70-17', '160/60-17', 2, 12000, null),
  ('honda-cb650r',       '120/70-17', '180/55-17', 4, 12000, 38400),
  ('honda-cbr650r',      '120/70-17', '180/55-17', 4, 12000, 38400),
  ('honda-cbr600rr',     '120/70-17', '180/55-17', 4, 12000, 24000)
) v(slug, front_tyre, rear_tyre, cylinders, service_km, valve_km)
where m.slug = v.slug;
