-- Each account reads only its own weekly summary and can't write one; any
-- signed-in account may ask for its own summary now (weekly-summary.yml
-- with the account as input), once every 2 minutes.
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', false);
insert into public.weekly_summaries (user_id, since, until, summary) values
  ('00000000-0000-0000-0000-0000000000a1', now() - interval '7 days', now(), '{"live": 3}'),
  ('00000000-0000-0000-0000-0000000000b1', now() - interval '7 days', now(), '{"live": 5}');

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  assert (select array_agg(summary->>'live') from public.weekly_summaries) = array['5'],
    'an account reads only its own summary';
  begin
    update public.weekly_summaries set summary = '{}';
    assert false, 'a summary was changed from the app';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.start_workflow('weekly-summary.yml');
    assert false, 'started without the token';
  exception when sqlstate '55000' then null;
  end;
end $$;
reset role;

set local role anon;
do $$
begin
  perform count(*) from public.weekly_summaries;
  assert false, 'anon read the summaries';
exception when insufficient_privilege then null;
end $$;
reset role;

insert into vault.secrets (name, secret) values ('github_dispatch_token', 'ghp_test');
insert into extensions.http_replies values
  ('POST', 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/weekly-summary.yml/dispatches', 204, '');

set local role authenticated;
do $$
begin
  assert public.start_workflow('weekly-summary.yml') = now();
  begin
    perform public.start_workflow('weekly-summary.yml');
    assert false, 'summary asked for twice';
  exception when sqlstate '55006' then null;
  end;
end $$;

set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  perform public.start_workflow('weekly-summary.yml');
  assert false, 'an anonymous session asked for a summary';
exception when sqlstate '42501' then null;
end $$;
reset role;

do $$
declare
  v_call record;
begin
  select * into strict v_call from extensions.http_calls;
  assert v_call.content::jsonb = '{"ref": "main", "inputs":
    {"account": "00000000-0000-0000-0000-0000000000b1"}}'::jsonb, v_call.content;
  update public.workflow_starts set started_at = now() - interval '3 minutes';
end $$;

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
select public.start_workflow('weekly-summary.yml');
reset role;
