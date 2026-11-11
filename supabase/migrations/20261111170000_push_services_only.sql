-- Web Push only to the browsers' own push services (N.57). The collector
-- posts every alert to the address a device saved, and any https address
-- was accepted: an account could have had the collector call a server of
-- its choosing. The hosts are the ones browsers give: Chrome and the
-- browsers built on it (fcm.googleapis.com, the older
-- android.googleapis.com), Safari (*.push.apple.com), Firefox
-- (*.push.services.mozilla.com) and Windows (*.notify.windows.com); =
-- the collector's `pushServiceHosts`, which refuses the others too
-- (`web_push_hosts_test.dart` reads schema.sql). The Android app's
-- `fcm:` rows are unchanged.
create function public.push_endpoint_allowed(p_endpoint text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(lower(p_endpoint) ~ (
    '^https://([a-z0-9-]+\.)*'
    '(fcm\.googleapis\.com|android\.googleapis\.com|push\.apple\.com'
    '|push\.services\.mozilla\.com|notify\.windows\.com)(:443)?/'), false)
$$;

revoke all on function public.push_endpoint_allowed(text)
  from public, anon, authenticated;

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text)
returns void
language plpgsql
security definer
set search_path = ''
as $_$
declare
  android boolean := p_endpoint ~ '^fcm:[A-Za-z0-9_:.-]{20,}$';
begin
  perform public.require_account();

  if not android
     and (not public.push_endpoint_allowed(p_endpoint)
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
$_$;

-- Devices saved to any other address can never be reached now.
delete from public.push_subscriptions
where endpoint not like 'fcm:%'
  and not public.push_endpoint_allowed(endpoint);
