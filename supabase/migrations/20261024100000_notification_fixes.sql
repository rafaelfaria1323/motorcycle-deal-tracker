-- Bugs found in a review of the notifications:
-- * pending_notifications also gives each alert's age, so the collector
--   tries a failed push again for a day and no longer pushes old news;
--   it now reads up to 200 a run (was 20, oldest first, so a busy run
--   pushed the rest hours late).
-- * Asking for the weekly summary waits 2 minutes per account, as the
--   app says (it held every other account back).
drop function public.pending_notifications(integer);

create function public.pending_notifications(p_limit integer default 200)
returns table (
  alert_id    uuid,
  user_id     uuid,
  listing_id  uuid,
  type        public.alert_type,
  old_price   numeric,
  new_price   numeric,
  brand       text,
  model       text,
  year        integer,
  mileage     integer,
  price       numeric,
  deal_score  smallint,
  location    text,
  url         text,
  to_telegram boolean,
  created_at  timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.user_id, l.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text,
         exists (select 1 from public.app_admins ad where ad.user_id = a.user_id),
         a.created_at
  from public.alerts a
  join public.listings l on l.id = a.listing_id
  join auth.users u on u.id = a.user_id
  where a.notified_at is null
    and not coalesce(u.is_anonymous, false)
  order by a.created_at
  limit p_limit
$$;

revoke all on function public.pending_notifications(integer)
  from public, anon, authenticated;

create or replace function public.start_workflow(p_workflow text, p_kind text default null)
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
               and (p_workflow = 'collect.yml' or w.started_by = auth.uid())
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

