-- Every catalog model, including those added before automatic searches,
-- has both sources. Existing filters remain authoritative.
do $$
begin
  assert not exists (
    select 1 from public.motorcycles
    where nullif(btrim(olx_search), '') is null
       or nullif(btrim(standvirtual_search), '') is null
  ), 'existing models are backfilled with both sources';
end $$;

insert into public.site_models
  (source, make_id, make_name, model_id, model_name)
values
  ('standvirtual', 'honda', 'Honda', 'forza', 'Forza'),
  ('olx', 'honda', 'Honda', 'cb', 'CB'),
  ('standvirtual', 'kawasaki', 'Kawasaki', 'z650', 'Z650'),
  ('olx', 'kawasaki-olx', 'Kawasaki', 'z-650', 'Z 650');

do $$
declare
  refused boolean := false;
begin
  assert public.catalog_search_url('olx', 'Honda', 'Forza 350')
    = 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/q-forza-350/',
    'an unknown OLX model uses words within the known brand, not a guessed model id';
  assert public.catalog_search_url('standvirtual', 'Norton', 'V4 SV')
    = 'https://www.standvirtual.com/motos/q-norton-v4-sv',
    'an unknown brand includes both names in the word search';
  assert public.catalog_search_url('olx', ' KAWASAKI ', 'Z-650')
    = 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/kawasaki-olx/'
      '?search%5Bfilter_enum_modelo%5D%5B0%5D=z-650',
    'known filters use that source''s ids, matching names without punctuation';
  assert public.catalog_search_url('standvirtual', 'Yamaha', 'Ténéré 700')
    = 'https://www.standvirtual.com/motos/q-yamaha-ténéré-700',
    'word searches keep accented letters';
  assert public.catalog_search_url('standvirtual', 'Yamaha', U&'Te\0301ne\0301re\0301 700')
    = 'https://www.standvirtual.com/motos/q-yamaha-ténéré-700',
    'decomposed accents are normalized rather than splitting search words';
  assert public.catalog_search_url('standvirtual', 'Norton', 'V4 / SV?')
    = 'https://www.standvirtual.com/motos/q-norton-v4-sv',
    'names cannot introduce path segments or query parameters';
  begin
    perform public.catalog_search_url('olx', 'Honda', ' --- ');
  exception when invalid_parameter_value then refused := true;
  end;
  assert refused, 'an empty word search is refused, never the whole market';

  refused := false;
  begin
    perform public.catalog_search_url('other', 'Honda', 'Forza');
  exception when invalid_parameter_value then refused := true;
  end;
  assert refused, 'an unsupported source is refused';

  assert not has_function_privilege('authenticated',
    'public.catalog_search_url(text,text,text)', 'execute'),
    'search construction stays internal';
end $$;

-- A malformed site id must never be copied into a generated address.
insert into public.site_models
  (source, make_id, make_name, model_id, model_name)
values ('olx', '../outside', 'Unsafe', 'bad?query=1', 'Example');
do $$
begin
  assert public.catalog_search_url('olx', 'Unsafe', 'Example')
    = 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/q-unsafe-example/',
    'unusable site ids fall back to safe search words';
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1');
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  added uuid;
  filtered uuid;
  hinted uuid;
begin
  added := public.add_catalog_model(' Norton ', ' V4 SV ', 2022);
  assert (select brand = 'Norton' and model = 'V4 SV' and min_year = 2022
      and olx_search =
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/q-norton-v4-sv/'
      and standvirtual_search = 'https://www.standvirtual.com/motos/q-norton-v4-sv'
    from public.motorcycles where id = added),
    'names and year alone create searches for both sites';
  assert (select tracked and min_year = 2022 from public.user_models
    where motorcycle_id = added and user_id = auth.uid()),
    'the account still follows the model it adds';

  filtered := public.add_catalog_model('Kawasaki', 'Z650', 2023);
  assert (select olx_search =
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/kawasaki-olx/'
        '?search%5Bfilter_enum_modelo%5D%5B0%5D=z-650'
      and standvirtual_search = 'https://www.standvirtual.com/motos/kawasaki/z650'
    from public.motorcycles where id = filtered),
    'both known source filters are preferred to word searches';

  hinted := public.add_catalog_model('Honda', 'Forza 350', 2021, null,
    'https://www.standvirtual.com/motos/honda/forza/q-350');
  assert (select olx_search =
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/q-forza-350/'
      and standvirtual_search = 'https://www.standvirtual.com/motos/honda/forza/q-350'
      and engine_cc_min = 315 and engine_cc_max = 385
    from public.motorcycles where id = hinted),
    'older picker calls keep their filter and gain the missing source and engine range';
end $$;

set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.add_catalog_model('Norton', 'Atlas', 2022);
    raise exception 'an anonymous session added a model without addresses';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The invariant also covers direct service-role writes and cleared URLs.
insert into public.motorcycles
  (brand, model, slug, min_year, olx_search, standvirtual_search)
values ('Honda', 'PCX', 'honda-pcx-auto', 2020,
  'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/q-pcx/', null);
update public.motorcycles
set olx_search = null, standvirtual_search = ' '
where slug = 'honda-pcx-auto';
do $$
begin
  assert (select olx_search =
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/q-pcx/'
      and standvirtual_search = 'https://www.standvirtual.com/motos/honda/q-pcx'
    from public.motorcycles where slug = 'honda-pcx-auto'),
    'clearing either source rebuilds it rather than disabling collection';
end $$;

alter table public.motorcycles disable trigger motorcycles_ensure_searches;
do $$
declare
  refused text;
begin
  begin
    update public.motorcycles set olx_search = null where slug = 'honda-pcx-auto';
  exception when check_violation then
    get stacked diagnostics refused = constraint_name;
  end;
  assert refused = 'motorcycles_both_source_searches',
    'the table constraint also prevents a missing source if the trigger is bypassed';
end $$;
alter table public.motorcycles enable trigger motorcycles_ensure_searches;
