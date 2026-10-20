-- Who may read and change what: listings are public; run logs and catalog
-- changes need a signed-in (not anonymous) account; the collector's
-- functions are not callable from the app.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1');
insert into public.collector_runs (started_at, status) values (now(), 'ok');

set local role anon;
do $$
begin
  perform count(*) from public.listings;
  perform count(*) from public.source_data_quality;
  perform count(*) from public.model_price_summary;
  assert (select count(*) from public.collector_runs) = 0, 'anon sees no runs';
  begin
    perform public.set_model_tracked((select id from public.motorcycles limit 1), false);
    raise exception 'anon changed the catalog';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.recalculate_deal_scores();
    raise exception 'anon ran a collector function';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  assert (select count(*) from public.collector_runs) = 0, 'an anonymous session sees no runs';
  begin
    perform public.set_model_tracked((select id from public.motorcycles limit 1), false);
    raise exception 'an anonymous session changed the catalog';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  assert (select count(*) from public.collector_runs) = 1, 'the account sees the runs';
  perform public.set_model_tracked((select id from public.motorcycles where slug = 'yamaha-r1'), true);
  assert (select is_active from public.motorcycles where slug = 'yamaha-r1'), 'the account changed it';
end $$;
reset role;
