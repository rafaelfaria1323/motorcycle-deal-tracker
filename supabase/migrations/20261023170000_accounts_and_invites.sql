-- Accounts from the app instead of by hand in Supabase: an admin creates an
-- invite (a link with a one-time code) and shares it; whoever opens it
-- chooses their email and password and the account is made there and then,
-- already confirmed (there is no SMTP to send confirmation emails). Admins
-- also see the accounts, make or unmake other admins and remove accounts.
--
-- Accounts are made through Supabase Auth's own admin API (never by
-- writing auth.users), called from here with the http extension and the
-- service-role key, which the collector stores in the Vault on each run
-- (store_service_access). Until its first run after this migration,
-- redeeming an invite says the accounts are not available yet.

create extension if not exists http with schema extensions;

-- Who may manage accounts. The oldest real account (the owner, who made
-- the others by hand) is the first admin.
create table public.app_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

create policy "Users see whether they are admins"
  on public.app_admins
  for select
  to authenticated
  using (user_id = (select auth.uid()));

insert into public.app_admins (user_id)
select u.id
from auth.users u
where not coalesce(u.is_anonymous, false)
order by u.created_at, u.id
limit 1;

-- Security invoker: the caller reads only its own app_admins row anyway.
create function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.app_admins a where a.user_id = auth.uid())
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create function public.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only an admin can do this' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.require_admin() from public, anon, authenticated;

-- One invite = one account. The code is the secret in the link (122 random
-- bits); it works once, for 14 days. Admins read and delete them (deleting
-- one that is not used yet cancels it).
create table public.invites (
  code       text primary key
               default translate(encode(uuid_send(gen_random_uuid()), 'base64'),
                                 '+/=', '-_'),
  note       text check (char_length(note) <= 80),
  created_by uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  used_at    timestamptz,
  used_by    uuid references auth.users (id) on delete set null
);

create index invites_created_by_idx on public.invites (created_by);
create index invites_used_by_idx on public.invites (used_by);

alter table public.invites enable row level security;

create policy "Admins read invites"
  on public.invites
  for select
  to authenticated
  using ((select public.is_admin()));

create policy "Admins delete invites"
  on public.invites
  for delete
  to authenticated
  using ((select public.is_admin()));

-- The address and key Supabase Auth's admin API is called with: the
-- collector's own (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY), refreshed on
-- every run so a rotated key follows by itself.
create function public.store_service_access(p_url text, p_key text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name   text;
  v_value  text;
  v_id     uuid;
  v_stored text;
begin
  if p_url not like 'http%://%' or nullif(btrim(p_key), '') is null then
    raise exception 'Invalid service access' using errcode = '22023';
  end if;
  foreach v_name in array array['service_url', 'service_role_key'] loop
    v_value := case v_name when 'service_url' then rtrim(btrim(p_url), '/')
                           else btrim(p_key) end;
    select s.id, s.decrypted_secret into v_id, v_stored
    from vault.decrypted_secrets s where s.name = v_name;
    if v_id is null then
      perform vault.create_secret(v_value, v_name, 'Supabase Auth admin API (collector)');
    elsif v_stored is distinct from v_value then
      perform vault.update_secret(v_id, v_value);
    end if;
  end loop;
end;
$$;

revoke all on function public.store_service_access(text, text) from public, anon, authenticated;

-- One request to Supabase Auth's admin API ('/admin/users...'); its status
-- and JSON answer. Raises 55000 when the collector has not stored the
-- access yet.
create function public.auth_admin_request(p_method text, p_path text, p_body jsonb default null)
returns table (status integer, body jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url      text;
  v_key      text;
  v_response extensions.http_response;
begin
  select s.decrypted_secret into v_url
  from vault.decrypted_secrets s where s.name = 'service_url';
  select s.decrypted_secret into v_key
  from vault.decrypted_secrets s where s.name = 'service_role_key';
  if v_url is null or v_key is null then
    raise exception 'Accounts are not available until the next collection'
      using errcode = '55000';
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '15000');
  v_response := extensions.http((
    p_method,
    v_url || '/auth/v1' || p_path,
    array[extensions.http_header('apikey', v_key),
          extensions.http_header('Authorization', 'Bearer ' || v_key)],
    'application/json',
    p_body::text
  )::extensions.http_request);

  status := v_response.status;
  body := case when v_response.content ~ '^\s*[\[{]'
               then v_response.content::jsonb end;
  return next;
end;
$$;

revoke all on function public.auth_admin_request(text, text, jsonb) from public, anon, authenticated;

-- A new invite (admins); returns its code.
create function public.create_invite(p_note text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  perform public.require_admin();
  insert into public.invites (note, created_by)
  values (nullif(btrim(p_note), ''), auth.uid())
  returning code into v_code;
  return v_code;
end;
$$;

revoke all on function public.create_invite(text) from public, anon;
grant execute on function public.create_invite(text) to authenticated;

-- What the invite page shows before the form: 'ok', 'used', 'expired' or
-- 'unknown' (also a cancelled one). Says nothing else about the invite.
create function public.invite_status(p_code text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select case
              when i.used_at is not null then 'used'
              when i.expires_at <= now() then 'expired'
              else 'ok'
            end
     from public.invites i where i.code = p_code),
    'unknown')
$$;

revoke all on function public.invite_status(text) from public;
grant execute on function public.invite_status(text) to anon, authenticated;

-- Uses an invite: makes the account (confirmed, so it can sign in at once)
-- and marks the invite used. Called from the invite page by the visitor's
-- anonymous session, which then signs in with the new account.
create function public.redeem_invite(p_code text, p_email text, p_password text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email  text := lower(btrim(p_email));
  v_status integer;
  v_body   jsonb;
  v_user   uuid;
begin
  perform 1 from public.invites i
  where i.code = p_code and i.used_at is null and i.expires_at > now()
  for update;
  if not found then
    raise exception 'This invite cannot be used' using errcode = 'P0002';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Invalid email' using errcode = '22023';
  end if;
  if char_length(coalesce(p_password, '')) < 8 then
    raise exception 'The password needs at least 8 characters' using errcode = '22023';
  end if;

  select r.status, r.body into v_status, v_body
  from public.auth_admin_request('POST', '/admin/users', jsonb_build_object(
    'email', v_email, 'password', p_password, 'email_confirm', true)) r;

  if v_status = 422
     and coalesce(v_body ->> 'error_code', v_body ->> 'code') = 'email_exists' then
    raise exception 'This email already has an account' using errcode = '23505';
  elsif v_status = 422
     and coalesce(v_body ->> 'error_code', v_body ->> 'code') = 'weak_password' then
    raise exception 'The password is too weak' using errcode = '22023';
  elsif v_status not between 200 and 299 or v_body ->> 'id' is null then
    raise exception 'Supabase Auth answered % %', v_status,
      coalesce(v_body ->> 'msg', v_body ->> 'message', '')
      using errcode = '58000';
  end if;

  v_user := (v_body ->> 'id')::uuid;
  update public.invites
  set used_at = now(), used_by = v_user
  where code = p_code;
  return v_user;
end;
$$;

revoke all on function public.redeem_invite(text, text, text) from public;
grant execute on function public.redeem_invite(text, text, text) to anon, authenticated;

-- Every real account, for admins.
create function public.admin_accounts()
returns table (
  user_id         uuid,
  email           text,
  created_at      timestamptz,
  last_sign_in_at timestamptz,
  is_admin        boolean,
  is_me           boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
  select u.id, u.email::text, u.created_at, u.last_sign_in_at,
         exists (select 1 from public.app_admins a where a.user_id = u.id),
         u.id = auth.uid()
  from auth.users u
  where not coalesce(u.is_anonymous, false)
  order by u.created_at;
end;
$$;

revoke all on function public.admin_accounts() from public, anon;
grant execute on function public.admin_accounts() to authenticated;

-- Make another account an admin, or not (never yourself: there is always
-- at least the admin doing it).
create function public.set_admin(p_user uuid, p_admin boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_user = auth.uid() then
    raise exception 'You cannot change your own admin access' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u
                 where u.id = p_user and not coalesce(u.is_anonymous, false)) then
    raise exception 'Unknown account %', p_user using errcode = 'P0002';
  end if;
  if p_admin then
    insert into public.app_admins (user_id) values (p_user) on conflict do nothing;
  else
    delete from public.app_admins where user_id = p_user;
  end if;
end;
$$;

revoke all on function public.set_admin(uuid, boolean) from public, anon;
grant execute on function public.set_admin(uuid, boolean) to authenticated;

-- Remove another account (its searches, alerts, favourites and devices go
-- with it; its models stop being collected if nobody else follows them).
create function public.remove_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status  integer;
  v_models  uuid[];
  v_model   uuid;
begin
  perform public.require_admin();
  if p_user = auth.uid() then
    raise exception 'You cannot remove your own account' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u
                 where u.id = p_user and not coalesce(u.is_anonymous, false)) then
    raise exception 'Unknown account %', p_user using errcode = 'P0002';
  end if;

  select coalesce(array_agg(m.motorcycle_id), '{}') into v_models
  from public.user_models m where m.user_id = p_user and m.tracked;

  select r.status into v_status
  from public.auth_admin_request('DELETE', '/admin/users/' || p_user) r;
  if v_status not between 200 and 299 and v_status <> 404 then
    raise exception 'Supabase Auth answered %', v_status using errcode = '58000';
  end if;

  -- Auth deletes the user in its own transaction; drop what is ours now
  -- too, so the collection follows at once.
  delete from public.user_models where user_id = p_user;
  foreach v_model in array v_models loop
    perform public.refresh_collected_model(v_model);
  end loop;
end;
$$;

revoke all on function public.remove_account(uuid) from public, anon;
grant execute on function public.remove_account(uuid) to authenticated;

-- Telegram is the owner's chat: only admins' alerts go there (every
-- account's still go to its own devices).
drop function public.pending_notifications(integer);

create function public.pending_notifications(p_limit integer default 20)
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
  to_telegram boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.user_id, l.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text,
         exists (select 1 from public.app_admins ad where ad.user_id = a.user_id)
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
