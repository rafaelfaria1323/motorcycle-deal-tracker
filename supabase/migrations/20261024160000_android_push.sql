-- Notifications in the Android app: Web Push lives in browsers, so the app
-- receives them through Firebase Cloud Messaging instead. Its device is
-- stored with the browsers' ones, as `fcm:<registration token>` and no
-- encryption keys (FCM carries the message itself), so everything that
-- reads, forgets or removes devices stays the same; the collector sends to
-- each kind its own way.

alter table public.push_subscriptions
  drop constraint push_subscriptions_endpoint_check;

alter table public.push_subscriptions
  add constraint push_subscriptions_endpoint_check
  check (endpoint like 'https://%' or endpoint ~ '^fcm:[A-Za-z0-9_:.-]{20,}$');

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  android boolean := p_endpoint ~ '^fcm:[A-Za-z0-9_:.-]{20,}$';
begin
  perform public.require_account();

  if not android
     and (p_endpoint not like 'https://%'
          or nullif(btrim(p_p256dh), '') is null
          or nullif(btrim(p_auth), '') is null) then
    raise exception 'Invalid push subscription' using errcode = '22023';
  end if;

  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, auth.uid(),
          case when android then '' else btrim(p_p256dh) end,
          case when android then '' else btrim(p_auth) end)
  on conflict (endpoint) do update
  set user_id = excluded.user_id,
      p256dh = excluded.p256dh,
      auth = excluded.auth,
      created_at = now();
end;
$$;
