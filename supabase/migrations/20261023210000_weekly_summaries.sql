-- The weekly summary in the app instead of Telegram: each Monday the
-- collector (bin/weekly_summary.dart) makes every account's summary of its
-- own models' last 7 days, keeps it here (one row per account, the latest)
-- for the app's "Resumo da semana" page, and sends it to the account's
-- devices as a notification that opens that page.

create table public.weekly_summaries (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  -- The 7 days summed up: [since, until).
  since      timestamptz not null,
  until      timestamptz not null,
  -- Counts, new listings per model, the biggest drops and the best deals
  -- (collector/lib/src/notify/weekly_summary.dart, weeklySummaryJson).
  summary    jsonb not null,
  made_at    timestamptz not null default now()
);

-- Written only by the collector (service role); read by its owner.
alter table public.weekly_summaries enable row level security;
revoke all on public.weekly_summaries from anon, authenticated;
grant select on public.weekly_summaries to authenticated;

create policy "Users read their own summary"
  on public.weekly_summaries
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- "Enviar o resumo da semana" (Mais › Notificações, and the summary page):
-- any signed-in account may now start weekly-summary.yml, once every 2
-- minutes, for itself only: the dispatch passes the account as the
-- workflow's input `account`, so a summary asked for just before Monday's
-- (started by pg_cron with no input, for every account) can't take its
-- place. Otherwise as before (20261023200000_push_test_from_app.sql).
create or replace function public.start_workflow(p_workflow text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token    text;
  v_response extensions.http_response;
  v_at       timestamptz;
begin
  if p_workflow in ('push-test.yml', 'weekly-summary.yml') then
    perform public.require_account();
  else
    perform public.require_admin();
  end if;
  if p_workflow is null
     or p_workflow not in ('collect.yml', 'weekly-summary.yml', 'push-test.yml') then
    raise exception 'unknown workflow %', p_workflow using errcode = '22023';
  end if;

  -- One at a time per workflow, so two taps can't both pass the check.
  perform pg_advisory_xact_lock(hashtext('start_workflow ' || p_workflow));
  if exists (select 1 from public.workflow_starts w
             where w.workflow = p_workflow
               and w.started_at > now() - case p_workflow
                 when 'collect.yml' then interval '15 minutes'
                 else interval '2 minutes' end) then
    raise exception '% was started too recently', p_workflow
      using errcode = '55006';
  end if;

  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s where s.name = 'github_dispatch_token';
  if v_token is null then
    raise exception 'github_dispatch_token is not in the Vault' using errcode = '55000';
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '15000');
  v_response := extensions.http((
    'POST',
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
      || '/actions/workflows/' || p_workflow || '/dispatches',
    array[extensions.http_header('Authorization', 'Bearer ' || v_token),
          extensions.http_header('Accept', 'application/vnd.github+json'),
          extensions.http_header('X-GitHub-Api-Version', '2022-11-28'),
          extensions.http_header('User-Agent', 'motorcycle-deal-tracker')],
    'application/json',
    case p_workflow
      when 'weekly-summary.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object('account', auth.uid()))::text
      else '{"ref": "main"}'
    end
  )::extensions.http_request);

  -- 204 = started (200 when GitHub answers with the run's details).
  if v_response.status not in (200, 204) then
    raise exception 'GitHub answered % to %', v_response.status, p_workflow
      using errcode = '58000';
  end if;

  insert into public.workflow_starts (workflow, started_by)
  values (p_workflow, auth.uid())
  returning started_at into v_at;
  return v_at;
end;
$$;
