-- "Enviar notificação de teste" can send an example of each notification
-- (an alert of each type, the collection's health): start_workflow passes
-- the kind and the asking account to push-test.yml. A test notification
-- can be asked for every 30 seconds per account (was 2 minutes for
-- everyone), so each kind can be tried in a row.
drop function public.start_workflow(text);

create function public.start_workflow(p_workflow text, p_kind text default null)
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
  if p_kind is not null and (p_workflow <> 'push-test.yml' or p_kind not in (
       'test', 'new_listing', 'price_reduction', 'excellent_opportunity',
       'listing_removed', 'back_on_market', 'target_price_reached',
       'run_failed', 'run_blocked', 'run_recovered')) then
    raise exception 'unknown kind %', p_kind using errcode = '22023';
  end if;

  -- One at a time per workflow, so two taps can't both pass the check.
  perform pg_advisory_xact_lock(hashtext('start_workflow ' || p_workflow));
  if exists (select 1 from public.workflow_starts w
             where w.workflow = p_workflow
               and (p_workflow <> 'push-test.yml' or w.started_by = auth.uid())
               and w.started_at > now() - case p_workflow
                 when 'collect.yml' then interval '15 minutes'
                 when 'push-test.yml' then interval '30 seconds'
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
      when 'push-test.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object(
                             'account', auth.uid(),
                             'kind', coalesce(p_kind, 'test')))::text
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

revoke all on function public.start_workflow(text, text) from public, anon;
grant execute on function public.start_workflow(text, text) to authenticated;
