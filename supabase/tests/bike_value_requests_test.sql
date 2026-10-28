-- Valuing any brand and model (20261028160000_bike_value_any_model.sql):
-- a request for a model nobody follows collects it from the bike's year
-- minus 3; the collector answers it after a run that read it; 30 days on,
-- the model stops being collected.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false),
  ('00000000-0000-0000-0000-0000000000c1', true);

insert into public.collector_runs (started_at, status)
values (now() - interval '1 hour', 'ok');
update public.motorcycles set collected_since = now() - interval '2 days', min_year = 2015
where slug = 'yamaha-mt-07';

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';

do $$
declare
  v_id uuid;
  v_again uuid;
  r record;
begin
  -- An existing model is found by name, any case; nothing is followed.
  assert public.bike_value_model('yamaha', 'mt-07')
         = (select id from public.motorcycles where slug = 'yamaha-mt-07'),
    'an existing model is reused';

  v_id := public.bike_value_model('Kawasaki', 'Z650');
  assert (select not is_active and collected_since is null
          from public.motorcycles where id = v_id),
    'a new model is not collected until asked for';
  assert (select olx_search is not null and standvirtual_search is not null
          from public.motorcycles where id = v_id),
    'both sites get a search';
  assert not exists (select 1 from public.user_models where motorcycle_id = v_id),
    'nobody follows it';
  v_again := public.bike_value_model(' KAWASAKI ', 'z650');
  assert v_again = v_id, 'asked again: the same model';

  -- Not collected yet: the request waits and switches the collection on.
  select * into r from public.request_bike_value(v_id, 2019, 30000);
  assert not r.ready, 'waits for a collection';
  assert (select is_active and min_year = 2016 and collected_since = now()
          from public.motorcycles where id = v_id),
    'collected from the year minus 3, from now';
  assert (select waited and answered_at is null and user_id = auth.uid()
          from public.bike_value_requests where id = r.request_id),
    'stored as waiting';
  assert (select request_id from public.request_bike_value(v_id, 2019, 30000)) = r.request_id,
    'the same request again is not a new one';
  assert (select count(*) from public.bike_value_requests) = 1, 'one request';

  -- Collected followed model, its year in range, a run since: ready now.
  select * into r from public.request_bike_value(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'),
    2020);
  assert r.ready, 'collected models are ready';
  assert (select not waited and answered_at is not null
          from public.bike_value_requests where id = r.request_id),
    'answered at once';
end $$;

-- At most 3 waiting requests a day.
do $$
declare
  v_id uuid := (select id from public.motorcycles where slug = 'kawasaki-z650');
begin
  perform public.request_bike_value(v_id, 2018);
  perform public.request_bike_value(v_id, 2017);
  begin
    perform public.request_bike_value(v_id, 2016);
    assert false, 'a fourth waiting request is refused';
  exception when sqlstate '54000' then null;
  end;
  begin
    perform public.request_bike_value(v_id, 1985);
    assert false, 'years before 1990 are refused';
  exception when sqlstate '22023' then null;
  end;
end $$;

-- Anonymous sessions can't ask.
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.bike_value_model('Suzuki', 'SV650');
    assert false, 'anonymous: no new models';
  exception when sqlstate '42501' then null;
  end;
  assert (select count(*) from public.bike_value_requests) = 0,
    'nobody else sees the requests';
end $$;

-- The collector answers what its run read.
reset role;
do $$
declare
  v_id uuid := (select id from public.motorcycles where slug = 'kawasaki-z650');
  r record;
begin
  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price)
  select 'olx', 'z' || g, 'https://x/z' || g, v_id, 'Kawasaki', 'Z650', 2019, 30000, 5000 + g * 100
  from generate_series(1, 3) g;

  assert not exists (select 1 from public.answer_bike_value_requests(now() - interval '1 minute')),
    'a run that started before the collection answers nothing';
  assert (select count(*) from public.bike_value_requests where answered_at is null) = 3,
    'still waiting';

  update public.listings set last_seen_at = now() - interval '1 hour'
  where motorcycle_id = v_id;
  assert not exists (select 1 from public.answer_bike_value_requests(now())),
    'the run saw none of its ads: still waiting';
  update public.listings set last_seen_at = now() where motorcycle_id = v_id;

  select * into r from public.answer_bike_value_requests(now())
  where year = 2019;
  assert r.comparable_count = 3 and r.fair_price = 5200 and r.brand = 'Kawasaki',
    format('answered with the value: %s', row_to_json(r));
  assert not exists (select 1 from public.bike_value_requests where answered_at is null),
    'all answered';
  assert not exists (select 1 from public.answer_bike_value_requests(now())),
    'answered once';

  -- A day on, a run that saw none of its ads answers anyway (the model
  -- may have none).
  insert into public.bike_value_requests (user_id, motorcycle_id, year, waited, requested_at)
  values ('00000000-0000-0000-0000-0000000000a1', v_id, 2019, true, now() - interval '25 hours');
  update public.listings set last_seen_at = now() - interval '1 hour'
  where motorcycle_id = v_id;
  select * into r from public.answer_bike_value_requests(now());
  assert r.comparable_count = 3, 'answered a day on';

  -- 30 days later nobody asks any more: collection stops.
  assert public.expire_bike_value_models() = 0, 'recent requests keep it';
  update public.bike_value_requests set requested_at = now() - interval '31 days'
  where motorcycle_id = v_id;
  assert public.expire_bike_value_models() >= 1, 'expired';
  assert (select not is_active and collected_since is null
          from public.motorcycles where id = v_id), 'no longer collected';
  assert not exists (select 1 from public.listings where motorcycle_id = v_id),
    'its listings are unmatched';

  assert (select schedule from cron.job where jobname = 'expire-bike-value-models') = '29 3 * * *',
    'expires daily';
end $$;
