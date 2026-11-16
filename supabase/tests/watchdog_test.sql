-- No run for 9 hours keeps one notice for the admins (again after a day)
-- and starts notices.yml; the next run keeps the recovery (N.114).
insert into vault.secrets (name, secret) values ('github_dispatch_token', 'ghp_test');

do $$
begin
  assert public.check_collection_runs() is null, 'no run ever: nothing to say';

  insert into public.collector_runs (started_at, status)
  values (now() - interval '10 hours', 'ok');

  assert public.check_collection_runs() = 'collection_stopped', 'the warning';
  assert (select details ->> 'hours' from public.admin_notices
          where kind = 'collection_stopped') = '10',
    (select details::text from public.admin_notices);
  assert (select details ->> 'last_run' from public.admin_notices) ~ '^\d\d/\d\d \d\d:\d\d$';
  assert (select count(*) from net.calls
          where url like '%/actions/workflows/notices.yml/dispatches') = 1,
    'its sender started';
  assert (select warned_at from public.collection_watchdog) = now(), 'marked as said';

  assert public.check_collection_runs(now() + interval '23 hours') is null,
    'not repeated within a day';
  assert public.check_collection_runs(now() + interval '25 hours') = 'collection_stopped',
    'repeated after a day';
  assert (select details ->> 'hours' from public.admin_notices order by id desc limit 1) = '35';

  insert into public.collector_runs (started_at, status) values (now(), 'failed');
  assert public.check_collection_runs() = 'collection_resumed',
    'the next run is a recovery, whatever its status';
  assert (select warned_at from public.collection_watchdog) is null, 'cleared';
  assert public.check_collection_runs() is null, 'the recovery is said once';
  assert (select count(*) from public.admin_notices) = 3, 'three notices in all';

  assert exists (select from cron.job where jobname = 'collection-watchdog'
                 and schedule = '20 * * * *'), 'scheduled hourly';
end $$;

-- Notices: kept once within their quiet time, taken by one sender at a
-- time, sent once.
do $$
declare
  v_ids bigint[];
begin
  delete from public.admin_notices where true;
  assert public.add_admin_notice('tax_tables', '{"year": 2027}', interval '30 days') is not null;
  assert public.add_admin_notice('tax_tables', '{"year": 2027}', interval '30 days') is null,
    'the same notice within its quiet time';
  assert public.add_admin_notice('tax_tables', '{"year": 2028}', interval '30 days') is not null,
    'other details are another notice';
  begin
    perform public.add_admin_notice('telegram');
    assert false, 'an unknown kind';
  exception when check_violation then null;
  end;

  select array_agg(id order by id) into v_ids from public.take_admin_notices();
  assert cardinality(v_ids) = 2, 'both taken';
  assert not exists (select from public.take_admin_notices()), 'not taken twice';
  perform public.mark_admin_notice_sent(v_ids[1]);
  update public.admin_notices set taken_at = now() - interval '11 minutes' where true;
  assert (select array_agg(id) from public.take_admin_notices()) = array[v_ids[2]],
    'a notice not sent is taken again 10 minutes on; a sent one never';

  assert exists (select from cron.job where jobname = 'prune-admin-notices');
end $$;

-- Without the GitHub token a notice is still kept (a collection sends it).
do $$
begin
  delete from vault.secrets where name = 'github_dispatch_token';
  assert public.add_admin_notice('collection_resumed') is not null;
end $$;

-- The app can't read the notices or keep one.
set local role authenticated;
do $$
begin
  begin
    perform public.add_admin_notice('tax_tables');
    assert false, 'add_admin_notice is not callable from the app';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.admin_notices;
    assert false, 'the notices are not readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.collection_watchdog;
    assert false, 'the watchdog table is not readable';
  exception when insufficient_privilege then null;
  end;
end $$;
