-- The schedules live in pg_cron and start the workflows through GitHub's
-- workflow_dispatch API with the Vault token. collection_text.dart in the app
-- mirrors the collection hours (collection_due).
do $$
declare
  refused boolean := false;
begin
  assert (select schedule from cron.job where jobname = 'collect-listings') = '40 * * * *',
    'the collection job checks every hour at minute 40 (change collection_text.dart with it)';
  assert (select command from cron.job where jobname = 'collect-listings') like '%dispatch_collection()%',
    'the collection job starts collect.yml when due';

  -- Lisbon hours 0, 8, 12, 14, 16, 18, 20, in winter (UTC) and summer (UTC+1).
  assert (select array_agg(h order by h) from generate_series(0, 23) h
          where public.collection_due(timestamptz '2026-12-01 00:40+00' + h * interval '1 hour'))
       = array[0, 8, 12, 14, 16, 18, 20], 'winter: the Lisbon hours are UTC';
  assert (select array_agg(h order by h) from generate_series(0, 23) h
          where public.collection_due(timestamptz '2026-07-01 00:40+00' + h * interval '1 hour'))
       = array[7, 11, 13, 15, 17, 19, 23], 'summer: one hour earlier in UTC';
  assert public.dispatch_collection(timestamptz '2026-12-01 09:40+00') is null, 'not due: nothing';
  assert (select count(*) from net.calls) = 0, 'and nothing is sent';
  assert (select schedule from cron.job where jobname = 'weekly-summary') = '52 7 * * 1',
    'weekly summary on Mondays at 07:52';
  assert (select command from cron.job where jobname = 'weekly-summary') like '%dispatch_workflow(''weekly-summary.yml'')%',
    'the summary job starts weekly-summary.yml';
  assert (select schedule from cron.job where jobname = 'collection-watchdog') = '20 * * * *',
    'the watchdog every hour at minute 20';

  assert public.dispatch_workflow('collect.yml') is null, 'without the token nothing starts';
  assert (select count(*) from net.calls) = 0, 'and nothing is sent';

  begin
    perform public.dispatch_workflow('deploy-web.yml');
  exception when others then
    refused := sqlerrm like 'unknown workflow%';
  end;
  assert refused, 'only the scheduled workflows can be started';

  insert into vault.secrets values ('github_dispatch_token', 'ghp_test');
  assert public.dispatch_collection(timestamptz '2026-12-01 14:40+00') = 42, 'due: started';
  assert (select url from net.calls) like '%/collect.yml/dispatches', 'collect.yml';
  delete from net.calls where true;
  assert public.dispatch_workflow('weekly-summary.yml') = 42, 'the request id is returned';
  assert (select count(*) from net.calls) = 1, 'one request';
  assert (select url from net.calls) =
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker/actions/workflows/weekly-summary.yml/dispatches',
    'the workflow''s dispatch address';
  assert (select body from net.calls) = '{"ref": "main"}', 'runs main';
  assert (select headers ->> 'Authorization' from net.calls) = 'Bearer ghp_test', 'with the Vault token';
  assert (select headers ->> 'User-Agent' from net.calls) is not null, 'GitHub requires a user agent';
end $$;

set local role authenticated;
do $$
begin
  perform public.dispatch_workflow('collect.yml');
  raise exception 'the app started a workflow';
exception when insufficient_privilege then null;
end $$;
reset role;
