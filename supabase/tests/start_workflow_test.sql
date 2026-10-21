-- Admins start the collection or the weekly summary from the app through
-- GitHub's workflow_dispatch API (the http stub records each request).
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-0000000000a1');

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';

-- Other accounts can't, and can't read the starts.
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  begin
    perform public.start_workflow('collect.yml');
    assert false, 'a non-admin started a workflow';
  exception when sqlstate '42501' then null;
  end;
  assert (select count(*) from public.workflow_starts) = 0;
  begin
    insert into public.workflow_starts (workflow) values ('collect.yml');
    assert false, 'a start was written directly';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  begin
    perform public.start_workflow('deploy-web.yml');
    assert false, 'another workflow started';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.start_workflow('collect.yml');
    assert false, 'started without the token';
  exception when sqlstate '55000' then null;
  end;
end $$;
reset role;

insert into vault.secrets (name, secret) values ('github_dispatch_token', 'ghp_test');
insert into extensions.http_replies values
  ('POST', 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/collect.yml/dispatches', 204, ''),
  ('POST', 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/weekly-summary.yml/dispatches', 403,
   '{"message": "Resource not accessible"}');

set local role authenticated;
do $$
begin
  assert public.start_workflow('collect.yml') = now();

  -- Not again within 15 minutes; GitHub refusing is reported.
  begin
    perform public.start_workflow('collect.yml');
    assert false, 'started twice';
  exception when sqlstate '55006' then null;
  end;
  begin
    perform public.start_workflow('weekly-summary.yml');
    assert false, 'a refused start passed';
  exception when sqlstate '58000' then null;
  end;
end $$;
reset role;

do $$
declare
  v_call record;
begin
  select * into v_call from extensions.http_calls order by uri limit 1;
  assert v_call.uri like '%/actions/workflows/collect.yml/dispatches', v_call.uri;
  assert v_call.content::jsonb = '{"ref": "main"}'::jsonb, v_call.content;
  assert ('Authorization', 'Bearer ghp_test')::extensions.http_header = any (v_call.headers);
  assert (select array_agg(workflow) from public.workflow_starts) = array['collect.yml'],
    'only the accepted start is recorded';
  update public.workflow_starts set started_at = now() - interval '16 minutes';
end $$;

set local role authenticated;
select public.start_workflow('collect.yml');
reset role;
do $$
begin
  assert (select count(*) from public.workflow_starts) = 2, 'started again after 15 minutes';
end $$;

-- Any signed-in account may send itself a test notification (push-test.yml),
-- once every 2 minutes; anonymous sessions may not.
insert into extensions.http_replies values
  ('POST', 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/push-test.yml/dispatches', 204, '');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  assert public.start_workflow('push-test.yml') = now();
  begin
    perform public.start_workflow('push-test.yml');
    assert false, 'push test started twice';
  exception when sqlstate '55006' then null;
  end;
  begin
    perform public.start_workflow('collect.yml');
    assert false, 'a non-admin started the collection';
  exception when sqlstate '42501' then null;
  end;
end $$;

set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  perform public.start_workflow('push-test.yml');
  assert false, 'an anonymous session sent a test notification';
exception when sqlstate '42501' then null;
end $$;
reset role;

do $$
begin
  assert (select started_by from public.workflow_starts
          where workflow = 'push-test.yml') = '00000000-0000-0000-0000-0000000000b1';
  update public.workflow_starts set started_at = now() - interval '3 minutes'
  where workflow = 'push-test.yml';
end $$;

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
select public.start_workflow('push-test.yml');
reset role;
