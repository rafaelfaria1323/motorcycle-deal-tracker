-- The schedules live in pg_cron and start the workflows through GitHub's
-- workflow_dispatch API with the Vault token. collection_text.dart in the app
-- mirrors the collection schedule.
do $$
declare
  refused boolean := false;
begin
  assert (select schedule from cron.job where jobname = 'collect-listings') = '40 */4 * * *',
    'collection every 4 hours at minute 40 (change collection_text.dart with it)';
  assert (select command from cron.job where jobname = 'collect-listings') like '%dispatch_workflow(''collect.yml'')%',
    'the collection job starts collect.yml';
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
