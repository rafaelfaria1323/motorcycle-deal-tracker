-- Model specifications (N.75): torque, weight, seat height and tank of the
-- catalog models beside their power (N.63) and consumption (N.74), shown on
-- the ad ("Ficha técnica") and in the comparison; and the rider's height,
-- kept with the owner's figures, for "Cabe-me?" (seat height against it).
-- Never part of any score.

-- The makers' figures for the current generation; null unknown (a model an
-- account added: the app shows only what it has). Read by everyone with the
-- catalog.
alter table public.motorcycles
  add column torque_nm numeric(4, 1)
    constraint motorcycles_torque_nm check (torque_nm > 0 and torque_nm <= 300),
  add column weight_kg smallint
    constraint motorcycles_weight_kg check (weight_kg between 60 and 450),
  add column seat_height_mm smallint
    constraint motorcycles_seat_height_mm check (seat_height_mm between 500 and 1100),
  add column tank_l numeric(3, 1)
    constraint motorcycles_tank_l check (tank_l between 3 and 40);

comment on column public.motorcycles.torque_nm is
  'The maker''s maximum torque in Nm (current generation); null unknown.';
comment on column public.motorcycles.weight_kg is
  'The maker''s wet weight in kg (ready to ride, full tank); null unknown.';
comment on column public.motorcycles.seat_height_mm is
  'The maker''s standard seat height in mm; null unknown.';
comment on column public.motorcycles.tank_l is
  'The fuel tank in litres; null unknown.';

-- The makers' European spec sheets.
update public.motorcycles m
set torque_nm = v.torque,
    weight_kg = v.weight,
    seat_height_mm = v.seat,
    tank_l = v.tank
from (values
  ('yamaha-mt-07',        68.0, 183, 805, 14.0),
  ('yamaha-r7',           67.0, 188, 835, 13.0),
  ('yamaha-tracer-7',     67.0, 196, 835, 17.0),
  ('yamaha-r1',          113.3, 201, 855, 17.0),
  ('yamaha-r3',           29.6, 169, 780, 14.0),
  ('yamaha-r9',           93.0, 195, 830, 14.0),
  ('honda-cb125r',        11.6, 130, 816, 10.1),
  ('honda-cb300r',        27.5, 144, 799, 10.0),
  ('honda-cbr500r',       43.0, 192, 785, 17.1),
  ('honda-cb750-hornet',  75.0, 190, 795, 15.2),
  ('honda-cb650r',        63.0, 205, 810, 15.4),
  ('honda-cbr650r',       63.0, 209, 810, 15.4),
  ('honda-cbr600rr',      63.0, 193, 820, 18.1)
) v(slug, torque, weight, seat, tank)
where m.slug = v.slug;

-- The rider's height for "Cabe-me?"; null: not given. Owner-only like the
-- rest of the row.
alter table public.ownership_settings
  add column rider_height_cm smallint
    constraint ownership_settings_rider_height check (rider_height_cm between 120 and 220);

comment on column public.ownership_settings.rider_height_cm is
  'The rider''s height in cm, for the seat height check ("Cabe-me?"); null not given.';
