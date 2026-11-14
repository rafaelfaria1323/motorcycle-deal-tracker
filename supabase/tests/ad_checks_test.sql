-- "Avaliar um anúncio" (20261115100000_ad_checks.sql): an ad link is a
-- bike value request with the ad; it collects the model, and the run that
-- sees the ad answers it with the ad's scores.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false),
  ('00000000-0000-0000-0000-0000000000a2', false),
  ('00000000-0000-0000-0000-0000000000c1', true);

-- Links: the site and the ad's code, whatever the title words or query.
do $$
begin
  assert public.ad_link_source(
    'https://www.olx.pt/d/anuncio/kawasaki-z650-como-nova-IDHk3aB.html?reason=x') = 'olx',
    'an OLX ad';
  assert public.ad_link_source('https://m.olx.pt/d/pt/anuncio/z650-IDHk3aB.html') = 'olx',
    'the mobile and /pt/ addresses';
  assert public.ad_link_code('https://www.olx.pt/d/anuncio/outro-titulo-IDHk3aB.html#fotos')
         = 'IDHk3aB', 'the code';
  assert public.ad_link_source(
    'https://www.standvirtual.com/motos/anuncio/kawasaki-z-650-ID8Q1m16.html') = 'standvirtual',
    'a Standvirtual ad';
  assert public.ad_link_source('https://www.standvirtual.com/carros/anuncio/x-ID8Q1m16.html') is null,
    'cars are not motorcycles';
  assert public.ad_link_source('https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/') is null,
    'a search is no ad';
  assert public.ad_link_source('https://evil.example/olx.pt/d/anuncio/x-ID1.html') is null,
    'another host';
  assert public.ad_link_code('https://www.custojusto.pt/x-ID1.html') is null, 'another site';
end $$;

insert into public.collector_runs (started_at, status)
values (now() - interval '1 hour', 'ok');

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';

do $$
declare
  v_id uuid := public.bike_value_model('Kawasaki', 'Z650');
  r record;
begin
  begin
    perform public.request_ad_check('https://www.olx.pt/anuncio/z650', v_id, 2019);
    assert false, 'a link that is no ad is refused';
  exception when sqlstate '22023' then null;
  end;

  select * into r from public.request_ad_check(
    ' https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html?reason=x ', v_id, 2019, 30000);
  assert r.listing_id is null, 'not stored: waits';
  assert (select ad_url = 'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html'
                 and waited and answered_at is null
          from public.bike_value_requests where id = r.request_id),
    'stored without the query, waiting';
  assert (select is_active and min_year = 2016 and collected_since = now()
          from public.motorcycles where id = v_id),
    'the model is collected from the year minus 3';
  assert (select request_id from public.request_ad_check(
            'https://www.olx.pt/d/anuncio/outro-titulo-IDHk3aB.html', v_id, 2019))
         = r.request_id,
    'another address of the same ad (the title words changed) is the same request';
  assert (select request_id from public.request_ad_check(
            'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html', v_id, 2019))
         = r.request_id,
    'the same link again is not a new request';
  perform public.request_ad_check('https://www.olx.pt/d/anuncio/b-IDb.html', v_id, 2019);
  perform public.request_ad_check('https://www.olx.pt/d/anuncio/c-IDc.html', v_id, 2019);
  begin
    perform public.request_ad_check('https://www.olx.pt/d/anuncio/d-IDd.html', v_id, 2019);
    assert false, 'the daily cap is the valuations''';
  exception when sqlstate '54000' then null;
  end;
end $$;

-- Anonymous sessions can't ask; nobody else sees the requests.
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.request_ad_check('https://www.olx.pt/d/anuncio/x-IDHk3aB.html',
      (select id from public.motorcycles where slug = 'kawasaki-z650'), 2019);
    assert false, 'anonymous: refused';
  exception when sqlstate '42501' then null;
  end;
  assert (select count(*) from public.bike_value_requests) = 0, 'owner-only';
end $$;

-- The run that finds the ad answers with its scores.
reset role;
do $$
declare
  v_id uuid := (select id from public.motorcycles where slug = 'kawasaki-z650');
  v_ad uuid;
  r record;
begin
  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price, last_seen_at)
  select 'olx', 'olx.pt/' || g, 'https://www.olx.pt/d/anuncio/z650-IDz' || g || '.html',
         v_id, 'Kawasaki', 'Z650', 2019, 30000, 5000 + g * 100, now()
  from generate_series(1, 3) g;

  assert not exists (select 1 from public.answer_bike_value_requests(now())),
    'the run saw other ads of the model, not this one: still waiting';

  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price, deal_score, risk_score, scored_at,
                               last_seen_at)
  values ('olx', 'olx.pt/9', 'https://www.olx.pt/d/anuncio/titulo-novo-IDHk3aB.html',
          v_id, 'Kawasaki', 'Z650', 2019, 30000, 4800, 81, 12, now(), now())
  returning id into v_ad;
  assert public.listing_for_ad('https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html') = v_ad,
    'found by its code, whatever the title words';
  assert public.listing_for_ad('https://www.standvirtual.com/motos/anuncio/z-IDHk3aB.html') is null,
    'the code on the other site is another ad';

  select * into r from public.answer_bike_value_requests(now())
  where is_ad
  order by id limit 1;
  assert r.listing_id = v_ad and r.deal_score = 81 and r.risk_score = 12
         and r.brand = 'Kawasaki' and r.comparable_count >= 3,
    format('answered with the ad: %s', row_to_json(r));
  assert not exists (select 1 from public.bike_value_requests
                     where answered_at is null and ad_url like '%IDHk3aB%'),
    'the ad''s request answered';
  delete from public.bike_value_requests where answered_at is null;

  -- Not found a day on: answered without the ad.
  insert into public.bike_value_requests (user_id, motorcycle_id, year, waited,
                                          requested_at, ad_url)
  values ('00000000-0000-0000-0000-0000000000a1', v_id, 2019, true,
          now() - interval '25 hours', 'https://www.olx.pt/d/anuncio/nunca-IDnone.html');
  select * into r from public.answer_bike_value_requests(now());
  assert r.is_ad and r.listing_id is null and r.comparable_count >= 3,
    format('a day on, not found: %s', row_to_json(r));

  -- A plain valuation stays a valuation.
  insert into public.bike_value_requests (user_id, motorcycle_id, year, waited)
  values ('00000000-0000-0000-0000-0000000000a1', v_id, 2019, true);
  select * into r from public.answer_bike_value_requests(now());
  assert not r.is_ad and r.listing_id is null, 'not an ad check';

  begin
    insert into public.bike_value_requests (user_id, motorcycle_id, year, waited, ad_url)
    values ('00000000-0000-0000-0000-0000000000a1', v_id, 2019, true, 'https://x/y');
    assert false, 'only ad links are stored';
  exception when check_violation then null;
  end;
end $$;

-- A stored, scored ad is answered at once; the computed field links it.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a2';
do $$
declare
  r record;
begin
  select * into r from public.request_ad_check(
    'https://www.olx.pt/d/anuncio/x-IDHk3aB.html',
    (select id from public.motorcycles where slug = 'kawasaki-z650'), 2019);
  assert r.listing_id is not null, 'ready at once';
  assert (select not waited and answered_at is not null and public.ad_listing(b) = r.listing_id
          from public.bike_value_requests b where b.id = r.request_id),
    'answered, not counted against the cap, linked to the ad';
end $$;
