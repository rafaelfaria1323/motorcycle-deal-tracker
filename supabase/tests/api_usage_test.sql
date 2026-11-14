-- Outside APIs' calls (N.101): the collector adds each run's requests to
-- the Lisbon day's; admins read this month's and last month's per service.
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-0000000000a1');

do $$
declare
  v_today date := (now() at time zone 'Europe/Lisbon')::date;
  v_month date := date_trunc('month', now() at time zone 'Europe/Lisbon')::date;
begin
  perform public.record_api_usage('api_ninjas', 12);
  perform public.record_api_usage('api_ninjas', 3);
  perform public.record_api_usage('api_ninjas', 0);
  perform public.record_api_usage('api_ninjas', null);
  assert (select requests from public.api_usage
          where service = 'api_ninjas' and day = v_today) = 15, 'runs add up';
  assert (select count(*) from public.api_usage) = 1, 'nothing for no requests';

  insert into public.api_usage (service, day, requests) values
    ('api_ninjas', v_month - 1, 40),
    ('api_ninjas', v_month - interval '2 months', 7),
    ('gemini', v_month - interval '20 months', 5);
  perform public.record_api_usage('api_ninjas', 1);
  assert not exists (select 1 from public.api_usage where service = 'gemini'),
    'rows older than 13 months go';

  begin
    perform public.record_api_usage('openai', 1);
    assert false, 'an unknown service was stored';
  exception when check_violation then null;
  end;
end $$;

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  begin
    perform public.api_usage();
    assert false, 'a non-admin read the usage';
  exception when sqlstate '42501' then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
declare
  r record;
begin
  assert (select count(*) from public.api_usage()) = 2, 'both services';
  select * into r from public.api_usage() where service = 'api_ninjas';
  assert r.month_requests = 16 and r.last_month_requests = 40
         and r.last_used_on = (now() at time zone 'Europe/Lisbon')::date, r::text;
  select * into r from public.api_usage() where service = 'gemini';
  assert r.month_requests = 0 and r.last_month_requests = 0
         and r.last_used_on is null, r::text;
end $$;
reset role;

do $$
begin
  assert not has_table_privilege('authenticated', 'public.api_usage', 'select');
  assert not has_function_privilege('authenticated', 'public.record_api_usage(text, integer)', 'execute');
  assert not has_function_privilege('anon', 'public.api_usage()', 'execute');
end $$;
