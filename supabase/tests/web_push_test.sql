-- Web Push: each signed-in account saves its devices (a device moves to the
-- account that saved it last), sees and removes only its own; anonymous
-- sessions can't; the key pair is stored once, the private key in Vault.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false),
  ('00000000-0000-0000-0000-0000000000b1', false),
  ('00000000-0000-0000-0000-0000000000c1', true);

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
select public.save_push_subscription('https://web.push.apple.com/one', ' key1 ', 'auth1');
select public.save_push_subscription('https://fcm.googleapis.com/two', 'key2', 'auth2');
do $$
declare
  refused text;
begin
  assert (select count(*) from public.push_subscriptions) = 2, 'A has two devices';
  assert (select p256dh from public.push_subscriptions where endpoint like '%/one') = 'key1', 'trimmed';
  begin
    perform public.save_push_subscription('http://insecure', 'k', 'a');
  exception when invalid_parameter_value then refused := sqlerrm;
  end;
  assert refused = 'Invalid push subscription', 'only https push services';
  begin
    perform public.push_keys();
    raise exception 'an account read the private key';
  exception when insufficient_privilege then null;
  end;
end $$;

-- B signs in on A's first device: it moves to B.
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
select public.save_push_subscription('https://web.push.apple.com/one', 'key1b', 'auth1b');
delete from public.push_subscriptions;
do $$
begin
  assert (select count(*) from public.push_subscriptions) = 0, 'B removed its own device';
end $$;
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  assert (select array_agg(endpoint) from public.push_subscriptions)
         = array['https://fcm.googleapis.com/two'], 'A keeps only its other device';
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.save_push_subscription('https://web.push.apple.com/three', 'k', 'a');
    raise exception 'an anonymous session saved a device';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The key pair: none at first, stored once.
do $$
begin
  assert (select count(*) from public.push_keys()) = 0, 'no keys yet';
  assert public.store_push_keys('PUB', 'PRIV'), 'first pair stored';
  assert not public.store_push_keys('PUB2', 'PRIV2'), 'a second pair is refused';
  assert (select public_key = 'PUB' and private_key = 'PRIV' from public.push_keys()),
    'the first pair is kept';
end $$;

set local role anon;
do $$
begin
  assert (select public_key from public.push_config) = 'PUB', 'anyone reads the public key';
  assert (select count(*) from public.push_subscriptions) = 0, 'anon sees no devices';
end $$;
reset role;
