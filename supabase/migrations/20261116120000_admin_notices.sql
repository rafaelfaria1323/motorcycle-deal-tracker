-- N.114: the database's own warnings (the collection watchdog, the GitHub
-- token, the space pruning, and the yearly tax tables) reach the admins'
-- devices as notifications instead of Telegram. The database can't sign or
-- encrypt a push itself, so it keeps the notice in admin_notices and starts
-- notices.yml, whose collector step pushes it (bin/admin_notices.dart); the
-- next collection's report sends any still waiting (a start that GitHub
-- refused, e.g. with the token gone). Telegram's function goes.

create table public.admin_notices (
  id bigint generated always as identity primary key,
  kind text not null check (kind in (
    'collection_stopped', 'collection_resumed', 'github_token_refused',
    'github_token_expiring', 'listings_pruned', 'tax_tables')),
  details jsonb not null default '{}',
  created_at timestamptz not null default now(),
  -- Taken by a sender (a lease: another may take it 10 minutes on).
  taken_at timestamptz,
  sent_at timestamptz
);

create index admin_notices_waiting on public.admin_notices (id) where sent_at is null;

alter table public.admin_notices enable row level security;
revoke all on public.admin_notices from public, anon, authenticated;

-- Keeps a notice for the admins and starts its sender. With p_quiet_for, a
-- notice of the same kind and details kept within it is enough: none is
-- added (null returned).
create function public.add_admin_notice(
  p_kind text,
  p_details jsonb default '{}',
  p_quiet_for interval default null
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
begin
  if p_quiet_for is not null and exists (
    select 1 from public.admin_notices n
    where n.kind = p_kind
      and n.details = coalesce(p_details, '{}')
      and n.created_at > now() - p_quiet_for) then
    return null;
  end if;

  insert into public.admin_notices (kind, details)
  values (p_kind, coalesce(p_details, '{}'))
  returning id into v_id;
  perform public.dispatch_workflow('notices.yml');
  return v_id;
end;
$$;

revoke all on function public.add_admin_notice(text, jsonb, interval)
  from public, anon, authenticated;
grant execute on function public.add_admin_notice(text, jsonb, interval) to service_role;

-- The notices waiting to be sent, oldest first, taken for 10 minutes so two
-- senders at once (a collection's report and notices.yml) don't both send.
create function public.take_admin_notices()
returns setof public.admin_notices
language sql
security definer
set search_path = ''
as $$
  update public.admin_notices n
  set taken_at = now()
  where n.sent_at is null
    and (n.taken_at is null or n.taken_at < now() - interval '10 minutes')
  returning n.*
$$;

revoke all on function public.take_admin_notices() from public, anon, authenticated;
grant execute on function public.take_admin_notices() to service_role;

create function public.mark_admin_notice_sent(p_id bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.admin_notices n set sent_at = now()
  where n.id = p_id and n.sent_at is null
$$;

revoke all on function public.mark_admin_notice_sent(bigint) from public, anon, authenticated;
grant execute on function public.mark_admin_notice_sent(bigint) to service_role;

-- Sent ones are kept 90 days.
select cron.schedule('prune-admin-notices', '47 3 * * *',
  $$delete from public.admin_notices where sent_at < now() - interval '90 days'$$);

create or replace function public.dispatch_workflow(p_workflow text) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  if p_workflow not in ('collect.yml', 'weekly-summary.yml', 'photos.yml', 'notices.yml') then
    raise exception 'unknown workflow %', p_workflow;
  end if;

  select s.decrypted_secret into token
  from vault.decrypted_secrets s
  where s.name = 'github_dispatch_token';

  if token is null then
    raise warning 'github_dispatch_token is not in the Vault; % not started',
      p_workflow;
    return null;
  end if;

  return net.http_post(
    url := 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/' || p_workflow || '/dispatches',
    body := '{"ref": "main"}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || token,
      'Accept', 'application/vnd.github+json',
      'Content-Type', 'application/json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent', 'motorcycle-deal-tracker'
    ),
    timeout_milliseconds := 10000
  );
end;
$$;

-- The watchdog: returns the kind of notice it kept, if any.
create or replace function public.check_collection_runs(p_now timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  last_run timestamptz;
  warned   timestamptz;
begin
  select max(r.started_at) into last_run from public.collector_runs r;
  -- No run ever recorded: a new project, nothing has broken yet.
  if last_run is null then
    return null;
  end if;

  select w.warned_at into warned from public.collection_watchdog w;

  if last_run < p_now - interval '9 hours' then
    if warned is not null and warned > p_now - interval '24 hours' then
      return null;
    end if;
    perform public.add_admin_notice('collection_stopped', jsonb_build_object(
      'hours', floor(extract(epoch from p_now - last_run) / 3600)::int,
      'last_run', to_char(last_run at time zone 'Europe/Lisbon', 'DD/MM HH24:MI')));
    update public.collection_watchdog set warned_at = p_now where id;
    return 'collection_stopped';
  elsif warned is not null then
    perform public.add_admin_notice('collection_resumed');
    update public.collection_watchdog set warned_at = null where id;
    return 'collection_resumed';
  end if;
  return null;
end;
$$;

create or replace function public.check_github_token()
returns public.github_token_check
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token    text;
  v_response extensions.http_response;
  v_header   extensions.http_header;
  v_expires  timestamptz;
  v_row      public.github_token_check;
begin
  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s where s.name = 'github_dispatch_token';

  if v_token is null then
    update public.github_token_check
    set checked_at = now(), state = 'missing', http_status = null, expires_at = null
    where id
    returning * into v_row;
    return v_row;
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '10000');
  v_response := extensions.http((
    'GET',
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
      || '/actions/workflows/collect.yml',
    array[extensions.http_header('Authorization', 'Bearer ' || v_token),
          extensions.http_header('Accept', 'application/vnd.github+json'),
          extensions.http_header('X-GitHub-Api-Version', '2022-11-28'),
          extensions.http_header('User-Agent', 'motorcycle-deal-tracker')],
    null,
    null
  )::extensions.http_request);

  foreach v_header in array coalesce(v_response.headers, '{}') loop
    if lower(v_header.field) = 'github-authentication-token-expiration' then
      begin
        v_expires := v_header.value::timestamptz;
      exception when others then
        v_expires := null;
      end;
    end if;
  end loop;

  update public.github_token_check
  set checked_at = now(),
      state = case when v_response.status = 200 then 'ok' else 'refused' end,
      http_status = v_response.status,
      expires_at = v_expires
  where id
  returning * into v_row;

  if v_row.warned_on is distinct from current_date then
    if v_row.state = 'refused' then
      perform public.add_admin_notice('github_token_refused',
        jsonb_build_object('http_status', v_row.http_status));
    elsif v_expires < now() + interval '14 days' then
      perform public.add_admin_notice('github_token_expiring', jsonb_build_object(
        'expires_on', to_char(v_expires at time zone 'Europe/Lisbon', 'DD/MM/YYYY')));
    else
      return v_row;
    end if;
    update public.github_token_check set warned_on = current_date where id
    returning * into v_row;
  end if;
  return v_row;
end;
$$;

create or replace function public.prune_unfollowed_listings(
  p_limit_bytes bigint default 400 * 1024 * 1024,
  p_min_days integer default 30
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bytes bigint := pg_catalog.pg_database_size(pg_catalog.current_database());
  v_deleted integer;
begin
  if v_bytes < p_limit_bytes then
    return 0;
  end if;

  delete from public.listings l
  where l.status in ('removed', 'sold')
    and l.source in ('olx', 'standvirtual')
    and l.last_checked_at < now() - pg_catalog.make_interval(days => p_min_days)
    and not exists (select 1 from public.motorcycles m
                    where m.id = l.motorcycle_id and m.is_active)
    and not exists (select 1 from public.listing_favourites f where f.listing_id = l.id)
    and not exists (select 1 from public.alerts a where a.listing_id = l.id)
    and not exists (select 1 from public.listings o
                    where o.relisted_from = l.id or o.duplicate_of = l.id);
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    perform public.add_admin_notice('listings_pruned', jsonb_build_object(
      'database_mb', v_bytes / (1024 * 1024), 'deleted', v_deleted));
  end if;
  return v_deleted;
end;
$$;

drop function public.send_telegram(text);
