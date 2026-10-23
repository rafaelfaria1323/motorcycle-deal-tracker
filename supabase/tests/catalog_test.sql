-- Catalog changes from the app: adding a model (checked, trimmed, tracked at
-- once, never twice), its earliest year and its new-bike price.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1');
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  forza uuid;
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  refused text;
begin
  forza := public.add_catalog_model(' Honda ', ' Forza 350 ', 2021,
    ' https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/forza-350/ ',
    ' ', '{forza}', 320, 360);
  assert (select brand = 'Honda' and model = 'Forza 350' and slug = 'honda-forza-350'
                 and is_active and min_year = 2021 and aliases = '{forza}'
                 and olx_search like 'https://%/forza-350/'
                 and standvirtual_search =
                   'https://www.standvirtual.com/motos/q-honda-forza-350'
                 and engine_cc_min = 320 and engine_cc_max = 360
          from public.motorcycles where id = forza),
    'added trimmed and tracked, keeping OLX and generating the blank Standvirtual search';

  refused := null;
  begin
    perform public.add_catalog_model('honda', 'forza 350', 2021, null,
      'https://www.standvirtual.com/motos/honda/forza-350');
  exception when unique_violation then refused := sqlerrm;
  end;
  assert refused = 'honda forza 350 is already in the list', format('a second Forza 350: %s', refused);

  refused := null;
  begin
    perform public.add_catalog_model(' ', 'X', 2021, 'https://x');
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Brand and model%', 'a blank brand is refused';

  perform public.add_catalog_model('Norton', 'Atlas', 2021, ' ', null);
  assert (select olx_search like 'https://%/q-norton-atlas/'
                 and standvirtual_search like 'https://%/q-norton-atlas'
          from public.motorcycles where slug = 'norton-atlas'),
    'a model without addresses gets both searches';

  refused := null;
  begin
    perform public.add_catalog_model('Honda', 'X', 1989, 'https://x');
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Year 1989%', 'a year before 1990 is refused';

  refused := null;
  begin
    perform public.add_catalog_model('Honda', 'X', 2021, 'https://x', null, '{}', 500, 400);
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Engine size range%', 'a reversed engine range is refused';

  -- Without an engine size, the one in the name counts, 10 % either way.
  perform public.add_catalog_model('Honda', 'ADV 350', 2024, 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/');
  assert (select engine_cc_min = 315 and engine_cc_max = 385
          from public.motorcycles where model = 'ADV 350'), 'ADV 350: 315-385 cc';
  perform public.add_catalog_model('Honda', 'NT1100 Travel', 2024, 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/');
  assert (select engine_cc_min is null and engine_cc_max is null
          from public.motorcycles where model = 'NT1100 Travel'), 'no size at the end of the name: none';
  refused := null;
  begin
    perform public.add_catalog_model('Honda', 'X', 2021, 'https://example.com/honda');
  exception when check_violation then refused := 'refused';
  end;
  assert refused = 'refused', 'a search on another site is refused';
  assert (select count(*) from public.motorcycles where model = 'X') = 0, 'nothing refused was added';

  -- set_model_min_year (of a model the account follows)
  perform public.set_model_tracked(mt07, true);
  perform public.set_model_min_year(mt07, 2022);
  assert (select min_year from public.motorcycles where id = mt07) = 2022, 'earliest year changed';
  refused := null;
  begin
    perform public.set_model_min_year(mt07, extract(year from now())::int + 2);
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Year%out of range', 'a year after next year is refused';
  refused := null;
  begin
    perform public.set_model_min_year(gen_random_uuid(), 2022);
  exception when no_data_found then refused := sqlerrm;
  end;
  assert refused like 'Unknown model%', 'an unknown model is reported';

  -- set_model_new_price: dated today unless told; none clears the date too.
  perform public.set_model_new_price(forza, 6990);
  assert (select new_price_reference = 6990 and new_price_checked_at = current_date
          from public.motorcycles where id = forza), 'price dated today';
  perform public.set_model_new_price(forza, 7190, '2026-09-01');
  assert (select new_price_checked_at from public.motorcycles where id = forza) = '2026-09-01',
    'price with its own date';
  perform public.set_model_new_price(forza, null);
  assert (select new_price_reference is null and new_price_checked_at is null
          from public.motorcycles where id = forza), 'price removed with its date';
  refused := null;
  begin
    perform public.set_model_new_price(forza, 0);
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Price 0%', 'a zero price is refused';
  refused := null;
  begin
    perform public.set_model_new_price(forza, 250000);
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused like 'Price 250000%', 'an absurd price is refused';
end $$;

set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.add_catalog_model('Honda', 'X', 2021, 'https://x');
    raise exception 'an anonymous session added a model';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.set_model_new_price((select id from public.motorcycles limit 1), 1000);
    raise exception 'an anonymous session changed a price';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
