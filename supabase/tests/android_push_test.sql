-- Android app devices: saved as `fcm:<token>` without encryption keys;
-- anything else that isn't an https endpoint with keys is still refused.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false);

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
select public.save_push_subscription('fcm:dQw4w9WgXcQ:APA91bH-abc_DEF.123', 'ignored', null);
do $$
declare
  bad text;
  refused int := 0;
begin
  assert (select p256dh = '' and auth = '' from public.push_subscriptions
          where endpoint = 'fcm:dQw4w9WgXcQ:APA91bH-abc_DEF.123'), 'saved without keys';
  foreach bad in array array['fcm:short', 'fcm:has spaces in the token here', 'fcm:',
                             'gcm:dQw4w9WgXcQ:APA91bH-abc_DEF.123'] loop
    begin
      perform public.save_push_subscription(bad, 'k', 'a');
    exception when invalid_parameter_value then refused := refused + 1;
    end;
  end loop;
  assert refused = 4, 'malformed tokens refused';
  begin
    perform public.save_push_subscription('https://web.push.apple.com/x', '', 'a');
    raise exception 'a browser device without keys was saved';
  exception when invalid_parameter_value then null;
  end;
end $$;
reset role;
