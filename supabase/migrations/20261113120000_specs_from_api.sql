-- Model specifications from API Ninjas (N.76): the collector's weekly
-- step (bin/model_specs.dart, model-specs.yml) looks up the catalog
-- models whose figures are incomplete, fills only the empty ones and
-- reports where the API disagrees with a figure already typed. A model an
-- account added from the app gets its figures this way. Never a score.

-- When the API was last asked about the model (found or not): an
-- incomplete model is asked again only after 30 days.
alter table public.motorcycles
  add column specs_checked_at timestamptz;

comment on column public.motorcycles.specs_checked_at is
  'When API Ninjas was last asked for the model''s figures (N.76); null never.';

-- The models to look up: never asked (so the typed figures are checked
-- once), or missing a figure the API gives and not asked for p_days days.
create or replace function public.model_specs_to_check(p_days integer default 30)
returns table(
  id uuid,
  brand text,
  model text,
  aliases text[],
  excluded_words text[],
  engine_cc_min smallint,
  engine_cc_max smallint,
  power_kw numeric,
  torque_nm numeric,
  weight_kg smallint,
  seat_height_mm smallint,
  tank_l numeric,
  fuel_l_per_100km numeric,
  front_tyre text,
  rear_tyre text,
  cylinders smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.brand, m.model, m.aliases, m.excluded_words,
         m.engine_cc_min, m.engine_cc_max,
         m.power_kw, m.torque_nm, m.weight_kg, m.seat_height_mm, m.tank_l,
         m.fuel_l_per_100km, m.front_tyre, m.rear_tyre, m.cylinders
  from public.motorcycles m
  where m.specs_checked_at is null
     or (m.specs_checked_at < now() - make_interval(days => p_days)
         and (m.power_kw is null or m.torque_nm is null or m.weight_kg is null
              or m.seat_height_mm is null or m.tank_l is null
              or m.fuel_l_per_100km is null or m.front_tyre is null
              or m.rear_tyre is null or m.cylinders is null))
  order by m.brand, m.model;
$$;

revoke all on function public.model_specs_to_check(integer)
  from public, anon, authenticated;
grant execute on function public.model_specs_to_check(integer) to service_role;

-- Stores what the API gave for one model: only the empty figures are
-- filled, and only with a value the column allows (anything else is left
-- empty); the model is stamped as checked either way. Returns the names
-- of the figures filled.
create or replace function public.store_model_specs(p_id uuid, p_specs jsonb)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_power numeric := (p_specs ->> 'power_kw')::numeric;
  v_torque numeric := (p_specs ->> 'torque_nm')::numeric;
  v_weight numeric := (p_specs ->> 'weight_kg')::numeric;
  v_seat numeric := (p_specs ->> 'seat_height_mm')::numeric;
  v_tank numeric := (p_specs ->> 'tank_l')::numeric;
  v_fuel numeric := (p_specs ->> 'fuel_l_per_100km')::numeric;
  v_front text := p_specs ->> 'front_tyre';
  v_rear text := p_specs ->> 'rear_tyre';
  v_cylinders numeric := (p_specs ->> 'cylinders')::numeric;
  v_before public.motorcycles;
  v_after public.motorcycles;
  v_filled text[] := '{}'::text[];
begin
  -- Out of the columns' ranges: unknown.
  if not (round(v_power, 1) > 0 and round(v_power, 1) <= 250) then v_power := null; end if;
  if not (round(v_torque, 1) > 0 and round(v_torque, 1) <= 300) then v_torque := null; end if;
  if not (round(v_weight) between 60 and 450) then v_weight := null; end if;
  if not (round(v_seat) between 500 and 1100) then v_seat := null; end if;
  if not (round(v_tank, 1) between 3 and 40) then v_tank := null; end if;
  if not (round(v_fuel, 1) between 1 and 15) then v_fuel := null; end if;
  if v_front !~ '^[0-9]{2,3}/[0-9]{2}-[0-9]{2}$' then v_front := null; end if;
  if v_rear !~ '^[0-9]{2,3}/[0-9]{2}-[0-9]{2}$' then v_rear := null; end if;
  if not (v_cylinders between 1 and 6) then v_cylinders := null; end if;

  select * into v_before from public.motorcycles m where m.id = p_id;
  if not found then
    return v_filled;
  end if;

  update public.motorcycles m
  set power_kw = coalesce(m.power_kw, round(v_power, 1)),
      torque_nm = coalesce(m.torque_nm, round(v_torque, 1)),
      weight_kg = coalesce(m.weight_kg, round(v_weight)::smallint),
      seat_height_mm = coalesce(m.seat_height_mm, round(v_seat)::smallint),
      tank_l = coalesce(m.tank_l, round(v_tank, 1)),
      fuel_l_per_100km = coalesce(m.fuel_l_per_100km, round(v_fuel, 1)),
      front_tyre = coalesce(m.front_tyre, v_front),
      rear_tyre = coalesce(m.rear_tyre, v_rear),
      cylinders = coalesce(m.cylinders, v_cylinders::smallint),
      specs_checked_at = now()
  where m.id = p_id
  returning * into v_after;

  if v_before.power_kw is distinct from v_after.power_kw then v_filled := array_append(v_filled, 'power_kw'); end if;
  if v_before.torque_nm is distinct from v_after.torque_nm then v_filled := array_append(v_filled, 'torque_nm'); end if;
  if v_before.weight_kg is distinct from v_after.weight_kg then v_filled := array_append(v_filled, 'weight_kg'); end if;
  if v_before.seat_height_mm is distinct from v_after.seat_height_mm then v_filled := array_append(v_filled, 'seat_height_mm'); end if;
  if v_before.tank_l is distinct from v_after.tank_l then v_filled := array_append(v_filled, 'tank_l'); end if;
  if v_before.fuel_l_per_100km is distinct from v_after.fuel_l_per_100km then v_filled := array_append(v_filled, 'fuel_l_per_100km'); end if;
  if v_before.front_tyre is distinct from v_after.front_tyre then v_filled := array_append(v_filled, 'front_tyre'); end if;
  if v_before.rear_tyre is distinct from v_after.rear_tyre then v_filled := array_append(v_filled, 'rear_tyre'); end if;
  if v_before.cylinders is distinct from v_after.cylinders then v_filled := array_append(v_filled, 'cylinders'); end if;
  return v_filled;
end;
$$;

revoke all on function public.store_model_specs(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.store_model_specs(uuid, jsonb) to service_role;
