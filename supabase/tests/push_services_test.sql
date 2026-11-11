-- Web Push only to the browsers' own push services
-- (20261111170000_push_services_only.sql).
do $$
begin
  assert public.push_endpoint_allowed('https://fcm.googleapis.com/fcm/send/abc');
  assert public.push_endpoint_allowed('https://web.push.apple.com/QABC');
  assert public.push_endpoint_allowed('https://updates.push.services.mozilla.com/wpush/v2/x');
  assert public.push_endpoint_allowed('https://wns2-db5p.notify.windows.com/w/?token=x');
  assert public.push_endpoint_allowed('https://FCM.googleapis.com:443/x');
  assert not public.push_endpoint_allowed('https://example.com/fcm.googleapis.com/');
  assert not public.push_endpoint_allowed('https://fcm.googleapis.com.example.com/x');
  assert not public.push_endpoint_allowed('https://fcm.googleapis.com@example.com/x');
  assert not public.push_endpoint_allowed('https://notfcm.googleapis.com/x');
  assert not public.push_endpoint_allowed('https://fcm.googleapis.com:8443/x');
  assert not public.push_endpoint_allowed('https://fcm.googleapis.com');
  assert not public.push_endpoint_allowed('http://fcm.googleapis.com/x');
  assert not public.push_endpoint_allowed(null);
end $$;
