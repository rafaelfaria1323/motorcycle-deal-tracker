-- Notifications on the phone from the app itself (Web Push), per account,
-- instead of one Telegram chat: each device that turns them on in Mais
-- stores its push subscription here; after each run the collector sends
-- the account's new alerts to its devices, and a tap opens the listing in
-- the app. On the iPhone this works in the home-screen app (iOS 16.4+).

create table public.push_subscriptions (
  -- The push service's address for this device; unique, so a device that
  -- signs in to another account moves to it.
  endpoint     text primary key check (endpoint like 'https://%'),
  user_id      uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  -- The browser's encryption keys (base64url).
  p256dh       text not null,
  auth         text not null,
  created_at   timestamptz not null default now(),
  last_sent_at timestamptz
);

create index push_subscriptions_user_id_idx on public.push_subscriptions (user_id);

-- Read and deleted by its owner; saved through save_push_subscription().
alter table public.push_subscriptions enable row level security;

create policy "Users read their own devices"
  on public.push_subscriptions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users remove their own devices"
  on public.push_subscriptions
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- Signed-in accounts only: anonymous sessions' alerts are never pushed.
create function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  if p_endpoint not like 'https://%'
     or nullif(btrim(p_p256dh), '') is null
     or nullif(btrim(p_auth), '') is null then
    raise exception 'Invalid push subscription' using errcode = '22023';
  end if;

  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, auth.uid(), btrim(p_p256dh), btrim(p_auth))
  on conflict (endpoint) do update
  set user_id = excluded.user_id,
      p256dh = excluded.p256dh,
      auth = excluded.auth,
      created_at = now();
end;
$$;

revoke all on function public.save_push_subscription(text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;

-- Our VAPID key pair, made by the collector on its first run: the public
-- key is what devices subscribe with (anyone may read it); the private
-- one stays in Vault.
create table public.push_config (
  id         boolean primary key default true check (id),
  public_key text not null
);

alter table public.push_config enable row level security;

create policy "Everyone reads the push key"
  on public.push_config
  for select
  to anon, authenticated
  using (true);

-- For the collector (service role): the key pair, or none yet.
create function public.push_keys()
returns table (public_key text, private_key text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.public_key, s.decrypted_secret
  from public.push_config c
  join vault.decrypted_secrets s on s.name = 'vapid_private_key'
$$;

-- Stores the first key pair; a later call keeps the one already stored
-- (devices are subscribed with it) and returns false.
create function public.store_push_keys(p_public_key text, p_private_key text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.push_config (public_key) values (p_public_key)
  on conflict (id) do nothing;
  if not found then
    return false;
  end if;
  perform vault.create_secret(p_private_key, 'vapid_private_key',
                              'Web Push private key (collector)');
  return true;
end;
$$;

revoke all on function public.push_keys() from public, anon, authenticated;
revoke all on function public.store_push_keys(text, text) from public, anon, authenticated;

-- Alerts still to send now say whose they are and which listing they open.
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
  url         text
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.user_id, l.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text
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
