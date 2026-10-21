-- Admins start the collection or the weekly summary from the app (Mais ›
-- Recolha de dados), outside their schedules. The same GitHub token as the
-- pg_cron jobs (Vault github_dispatch_token), but through the synchronous
-- http extension, so the app hears whether GitHub accepted. The fetching
-- rules are unchanged: the collector still enforces its per-run and daily
-- caps, so a run started here uses that day's budget. One start per
-- workflow every 15 minutes (a double tap, or a run still going).

create table public.workflow_starts (
  id         bigint generated always as identity primary key,
  workflow   text not null,
  started_by uuid,
  started_at timestamptz not null default now()
);

create index workflow_starts_recent on public.workflow_starts (workflow, started_at desc);

-- Written only through start_workflow; admins may read it.
alter table public.workflow_starts enable row level security;
revoke all on public.workflow_starts from anon, authenticated;
grant select on public.workflow_starts to authenticated;
create policy workflow_starts_admins on public.workflow_starts
  for select to authenticated using ((select public.is_admin()));

-- Errors: 42501 not an admin, 22023 unknown workflow, 55006 started in
-- the last 15 minutes, 55000 no token in the Vault, 58000 GitHub refused.
create function public.start_workflow(p_workflow text)
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
  perform public.require_admin();
  if p_workflow is null or p_workflow not in ('collect.yml', 'weekly-summary.yml') then
    raise exception 'unknown workflow %', p_workflow using errcode = '22023';
  end if;

  -- One at a time per workflow, so two taps can't both pass the check.
  perform pg_advisory_xact_lock(hashtext('start_workflow ' || p_workflow));
  if exists (select 1 from public.workflow_starts w
             where w.workflow = p_workflow
               and w.started_at > now() - interval '15 minutes') then
    raise exception '% was started less than 15 minutes ago', p_workflow
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
    '{"ref": "main"}'
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

revoke all on function public.start_workflow(text) from public, anon;
grant execute on function public.start_workflow(text) to authenticated;
