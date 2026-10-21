-- The GitHub token that starts the runs: checked against GitHub, its
-- expiry read from GitHub's header, Telegram told once a day when it is
-- refused or about to expire. (The http stub answers from http_replies.)
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-0000000000a1');
insert into vault.secrets (name, secret) values
  ('telegram_bot_token', 'bot'), ('telegram_chat_id', '1');

create temp table workflow_url as
select 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
       || '/actions/workflows/collect.yml' as uri;

do $$
declare
  v_row public.github_token_check;
begin
  assert (select schedule from cron.job where jobname = 'github-token-check') = '7 8 * * *';

  v_row := public.check_github_token();
  assert v_row.state = 'missing', v_row.state;
  assert (select count(*) from extensions.http_calls) = 0, 'GitHub asked without a token';

  -- A token GitHub accepts, far from expiring: nothing to say.
  insert into vault.secrets (name, secret) values ('github_dispatch_token', 'ghp_test');
  insert into extensions.http_replies
  select 'GET', uri, 200, '{}',
         array[('github-authentication-token-expiration',
                to_char(now() + interval '60 days', 'YYYY-MM-DD HH24:MI:SS') || ' UTC')
               ::extensions.http_header]
  from workflow_url;
  v_row := public.check_github_token();
  assert v_row.state = 'ok' and v_row.http_status = 200;
  assert v_row.expires_at between now() + interval '59 days' and now() + interval '61 days',
    v_row.expires_at::text;
  assert (select ('Authorization', 'Bearer ghp_test')::extensions.http_header = any (headers)
          from extensions.http_calls);
  assert (select count(*) from net.calls) = 0, 'warned about a token far from expiring';

  -- Five days left: one warning a day.
  update extensions.http_replies
  set headers = array[('github-authentication-token-expiration',
                       to_char(now() + interval '5 days', 'YYYY-MM-DD HH24:MI:SS') || ' UTC')
                      ::extensions.http_header];
  v_row := public.check_github_token();
  assert v_row.warned_on = current_date;
  assert (select body ->> 'text' from net.calls) like '%expira a%', (select body::text from net.calls);
  perform public.check_github_token();
  assert (select count(*) from net.calls) = 1, 'warned twice in a day';

  -- Refused: said the next day.
  update public.github_token_check set warned_on = current_date - 1;
  update extensions.http_replies set status = 401, headers = null;
  v_row := public.check_github_token();
  assert v_row.state = 'refused' and v_row.http_status = 401 and v_row.expires_at is null;
  assert (select count(*) from net.calls where body ->> 'text' like '%recusou%(HTTP 401)%') = 1;
end $$;

-- Admins only, from the app.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  begin
    perform public.github_token_status();
    assert false, 'a non-admin checked the token';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform 1 from public.github_token_check;
    assert false, 'the check is readable';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  assert (select state from public.github_token_status()) = 'refused';
end $$;
reset role;

-- A run without the new fields (the collector before this change) still
-- records.
do $$
begin
  insert into public.collector_runs (started_at, status) values (now(), 'ok');
  assert (select problems = '{}' and sites = '{}' and run_url is null
          from public.collector_runs order by id desc limit 1);
end $$;
