-- Visit planning (N.65): a favourite can carry the time the person goes
-- to see the bike, and the collector reminds them on their devices the
-- day before (the first run within 24 hours of the visit outside their
-- quiet hours).
alter table public.listing_favourites
  add column visit_at timestamptz,
  add column visit_reminded_at timestamptz;

-- A new or moved visit is reminded again; set by the database, so the app
-- only writes visit_at.
create function public.stamp_favourite_visit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.visit_at is distinct from old.visit_at then
    new.visit_reminded_at := null;
  end if;
  return new;
end;
$$;

revoke all on function public.stamp_favourite_visit() from public, anon, authenticated;

create trigger listing_favourites_visit_stamp
  before insert or update of visit_at on public.listing_favourites
  for each row execute function public.stamp_favourite_visit();

-- The visits to remind at [p_at] (the run's time): within the next 24
-- hours, not reminded yet, of accounts not in their quiet hours then.
-- The visit's day and time come in Lisbon time, with how many calendar
-- days away it is (0 today, 1 tomorrow), so the collector needs no time
-- zone rules.
create function public.pending_visit_reminders(p_at timestamptz)
returns table (
  user_id    uuid,
  listing_id uuid,
  visit_at   timestamptz,
  visit_day  integer,
  visit_time text,
  brand      text,
  model      text,
  year       integer,
  price      numeric,
  location   text,
  is_live    boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select f.user_id, f.listing_id, f.visit_at,
         ((f.visit_at at time zone 'Europe/Lisbon')::date
           - (p_at at time zone 'Europe/Lisbon')::date)::integer,
         to_char(f.visit_at at time zone 'Europe/Lisbon', 'HH24:MI'),
         l.brand, l.model, l.year, l.price, l.location,
         l.status in ('active', 'price_changed')
  from public.listing_favourites f
  join public.listings l on l.id = f.listing_id
  join auth.users u on u.id = f.user_id and not coalesce(u.is_anonymous, false)
  where f.visit_reminded_at is null
    and f.visit_at > p_at
    and f.visit_at <= p_at + interval '24 hours'
    and not public.account_quiet_at(f.user_id, p_at)
  order by f.visit_at, f.user_id, f.listing_id
$$;

revoke all on function public.pending_visit_reminders(timestamptz)
  from public, anon, authenticated;

-- Marks a reminder sent, only while the visit is still at that time (one
-- moved meanwhile is reminded again).
create function public.mark_visit_reminded(
  p_user uuid, p_listing uuid, p_visit_at timestamptz)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with marked as (
    update public.listing_favourites f
    set visit_reminded_at = now()
    where f.user_id = p_user
      and f.listing_id = p_listing
      and f.visit_at = p_visit_at
      and f.visit_reminded_at is null
    returning 1)
  select exists (select 1 from marked)
$$;

revoke all on function public.mark_visit_reminded(uuid, uuid, timestamptz)
  from public, anon, authenticated;

-- push-test.yml can send an example of the reminder.
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
       'run_failed', 'run_blocked', 'run_recovered', 'visit_reminder')) then
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
