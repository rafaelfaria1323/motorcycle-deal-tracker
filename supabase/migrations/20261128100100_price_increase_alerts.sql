-- Alerts when an ad's price goes up (N.125, Rafael: "an ad was one price
-- and the next morning it was 1000 € more expensive"). Only for bikes the
-- person follows: a favourite (a rise after it became one) or an ad an
-- active saved search already alerted about (an alert still shown). Each
-- rise of 1 % or more, once per person and price change; a rise from a
-- placeholder price (under 300 €) isn't one. Rises in the last day only,
-- so the first run doesn't bring back every old one.

create unique index alerts_one_increase_per_user_and_change
  on public.alerts (user_id, price_history_id)
  where type = 'price_increase';

create function public.generate_price_increase_alerts(p_min_rise_pct numeric default 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (
    user_id, saved_search_id, listing_id, type,
    old_price, new_price, price_history_id
  )
  select distinct on (w.user_id, c.history_id)
         w.user_id, w.saved_search_id, c.listing_id,
         'price_increase'::public.alert_type,
         c.old_price, c.new_price, c.history_id
  from (
    select h.id as history_id,
           h.listing_id,
           h.observed_at,
           h.price as new_price,
           lag(h.price) over (
             partition by h.listing_id order by h.observed_at, h.id
           ) as old_price
    from public.listing_price_history h
    where h.listing_id in (
      select r.listing_id from public.listing_price_history r
      where r.observed_at > now() - interval '1 day')
  ) c
  join (
    select f.user_id, f.listing_id, null::uuid as saved_search_id,
           f.created_at as since
    from public.listing_favourites f
    union all
    select a.user_id, a.listing_id, a.saved_search_id, a.created_at
    from public.alerts a
    join public.saved_searches s on s.id = a.saved_search_id
    where a.dismissed_at is null
      and a.type <> 'listing_removed'
      and s.is_active
  ) w on w.listing_id = c.listing_id
  where c.old_price >= 300
    and c.new_price > c.old_price
    and (c.new_price - c.old_price) / c.old_price * 100 >= p_min_rise_pct
    and c.observed_at > w.since
    and c.observed_at > now() - interval '1 day'
  -- A favourite first: its alert has no search to edit.
  order by w.user_id, c.history_id, w.saved_search_id nulls first
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_price_increase_alerts(numeric)
  from public, anon, authenticated;

create or replace function public.generate_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.generate_new_listing_alerts()
       + public.generate_price_reduction_alerts()
       + public.generate_price_increase_alerts()
       + public.generate_excellent_opportunity_alerts()
       + public.generate_listing_removed_alerts()
       + public.generate_favourite_alerts()
       + public.generate_back_on_market_alerts()
       + public.generate_target_price_alerts();
end;
$$;

-- The test notification of a rise too.
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
       'price_increase',
       'run_failed', 'run_blocked', 'run_recovered', 'visit_reminder',
       'bike_value_month', 'recall')) then
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
