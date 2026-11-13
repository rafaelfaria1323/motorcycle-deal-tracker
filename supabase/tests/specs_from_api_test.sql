-- Specifications from API Ninjas (N.76): which models are looked up, and
-- that storing fills only empty figures, within the columns' ranges.
insert into public.motorcycles (brand, model, slug, min_year, olx_search, standvirtual_search)
values ('Honda', 'Forza 350', 'honda-forza-350-test', 2021,
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/q-forza-350/',
        'https://www.standvirtual.com/motos/honda/q-forza-350');

do $$
declare
  v_id uuid := (select id from public.motorcycles where slug = 'honda-forza-350-test');
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v_filled text[];
begin
  -- Never asked: every model, so the typed figures are checked once.
  assert (select count(*) from public.model_specs_to_check(30))
       = (select count(*) from public.motorcycles);

  v_filled := public.store_model_specs(v_id, jsonb_build_object(
    'power_kw', 21.5, 'torque_nm', 31.5, 'weight_kg', 184.4,
    'seat_height_mm', 780, 'tank_l', 11.7, 'fuel_l_per_100km', 3.1,
    'front_tyre', '120/70-15', 'rear_tyre', '140/70-ZR14',
    'cylinders', 1));
  assert v_filled = array['power_kw', 'torque_nm', 'weight_kg', 'seat_height_mm',
                          'tank_l', 'fuel_l_per_100km', 'front_tyre', 'cylinders'],
    format('filled %s', v_filled);
  assert (select weight_kg from public.motorcycles where id = v_id) = 184;
  assert (select rear_tyre from public.motorcycles where id = v_id) is null,
    'a tyre size the column refuses stays empty';
  assert (select specs_checked_at from public.motorcycles where id = v_id) is not null;

  -- A typed figure is never replaced; out of range is unknown.
  v_filled := public.store_model_specs(v_mt07, jsonb_build_object(
    'seat_height_mm', 900, 'weight_kg', 20, 'tank_l', 99));
  assert (select seat_height_mm from public.motorcycles where id = v_mt07) = 805;
  assert not ('weight_kg' = any (v_filled)) and not ('tank_l' = any (v_filled));

  -- Asked now: only an incomplete model asked over 30 days ago comes back.
  update public.motorcycles set specs_checked_at = now() where true;
  assert (select count(*) from public.model_specs_to_check(30)) = 0;
  update public.motorcycles set specs_checked_at = now() - interval '31 days'
  where id = v_id;
  assert (select array_agg(id) from public.model_specs_to_check(30)) = array[v_id],
    'the model without a rear tyre is asked again';

  -- An unknown model stores nothing.
  assert public.store_model_specs(gen_random_uuid(), '{}') = '{}';
end $$;

-- Only the collector's role may call them.
set local role authenticated;
do $$
begin
  perform public.model_specs_to_check(30);
  assert false, 'authenticated read the models to check';
exception when insufficient_privilege then null;
end $$;
reset role;
