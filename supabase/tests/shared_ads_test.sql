-- The iPhone shortcut (20261115160000_shared_ads.sql): a personal key
-- drops ads read in Safari into its owner's inbox, and only there.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000005a1', false),
  ('00000000-0000-0000-0000-0000000005a2', false),
  ('00000000-0000-0000-0000-0000000005c1', true);
insert into public.account_languages (user_id, language)
values ('00000000-0000-0000-0000-0000000005a2', 'en');

-- Only real accounts make keys.
set local role authenticated;
set local test.jwt = '{"is_anonymous": true}';
set local test.uid = '00000000-0000-0000-0000-0000000005c1';
do $$
begin
  perform public.create_ad_import_key();
  assert false, 'an anonymous session makes no key';
exception when sqlstate '42501' then null;
end $$;

set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005a1';
create temporary table keys (owner text, key text) on commit drop;
grant all on keys to anon, authenticated;
do $$
declare
  v_old text;
  v_key text;
begin
  assert public.ad_import_key_created_at() is null, 'no key yet';
  v_old := public.create_ad_import_key();
  v_key := public.create_ad_import_key();
  assert v_key ~ '^[0-9a-f]{64}$', 'a long random key';
  assert v_key <> v_old, 'each key is new';
  assert public.ad_import_key_created_at() is not null, 'the key is known';
  insert into keys values ('old', v_old), ('a1', v_key);
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000005a2';
do $$
begin
  insert into keys values ('a2', public.create_ad_import_key());
end $$;

-- The shortcut calls as anon, with the key.
reset test.uid;
reset test.jwt;
set local role anon;
do $$
declare
  v_key text := (select key from keys where owner = 'a1');
  v_result jsonb;
begin
  begin
    perform public.receive_shared_ad((select key from keys where owner = 'old'),
                                     '{"url": "https://www.facebook.com/marketplace/item/1/"}');
    assert false, 'a replaced key is refused';
  exception when sqlstate '28000' then null;
  end;
  begin
    perform public.receive_shared_ad(null, '{"url": "https://x.pt/"}');
    assert false, 'no key is refused';
  exception when sqlstate '28000' then null;
  end;
  begin
    perform public.receive_shared_ad(v_key, '{"url": "javascript:alert(1)"}');
    assert false, 'only https links';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.receive_shared_ad(v_key, '"https://x.pt/"');
    assert false, 'the ad is an object';
  exception when sqlstate '22023' then null;
  end;

  v_result := public.receive_shared_ad(v_key, jsonb_build_object(
    'version', 4,
    'url', 'https://www.facebook.com/marketplace/item/123/',
    'title', 'Yamaha MT-07 2019',
    'description', 'Como nova. Ligue 912 345 678.',
    'price', '7 500 €',
    'lines', jsonb_build_array('Anunciado há 5 semanas em Lisboa', '', 'Conduzido 25 000 km', 42),
    'photos', jsonb_build_array('https://scontent.xx.fbcdn.net/a.jpg', 'http://insecure/b.jpg',
                                'https://scontent.xx.fbcdn.net/a.jpg', 7,
                                'https://scontent.xx.fbcdn.net/c.jpg')));
  assert v_result ->> 'message' = 'Enviado para o Deal Tracker: Yamaha MT-07 2019 (2 fotos).',
    'the notification, in the account''s language: ' || (v_result ->> 'message');
  assert not (v_result ->> 'outdated')::boolean, 'the script is current';

  v_result := public.receive_shared_ad(
    (select key from keys where owner = 'a2'),
    '{"url": "https://www.custojusto.pt/lisboa/motos/x-1"}');
  assert v_result ->> 'message' like 'Sent to Deal Tracker: ad (0 photos). The shortcut has a new version%',
    'English, and an old script is told: ' || (v_result ->> 'message');

  -- The shared shortcut: no key in the body, the key in its header.
  perform set_config('request.headers',
    jsonb_build_object('x-deal-tracker-key', (select key from keys where owner = 'a2'))::text, true);
  v_result := public.receive_shared_ad(null,
    '{"version": 4, "url": "https://www.custojusto.pt/lisboa/motos/x-2"}');
  assert v_result ->> 'message' = 'Sent to Deal Tracker: ad (0 photos).',
    'the header''s key, current script: ' || (v_result ->> 'message');
  -- A key in the body wins over the header.
  perform set_config('request.headers',
    '{"x-deal-tracker-key": "' || repeat('0', 64) || '"}', true);
  v_result := public.receive_shared_ad((select key from keys where owner = 'a2'),
    '{"version": 4, "url": "https://x.pt/body"}');
  assert v_result ->> 'message' like 'Sent%', 'the body''s key: ' || (v_result ->> 'message');
  begin
    perform public.receive_shared_ad(null, '{"url": "https://x.pt/"}');
    assert false, 'an unknown header key is refused';
  exception when sqlstate '28000' then null;
  end;
  perform set_config('request.headers', '', true);
end $$;

-- Each account sees its own ads, phone numbers gone.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005a1';
do $$
declare
  r record;
begin
  assert (select count(*) from public.my_shared_ads()) = 1, 'only its own ads';
  select * into r from public.my_shared_ads();
  assert r.description not like '%912%', 'no phone number: ' || r.description;
  assert r.price = '7 500 €', 'the price as shown';
  assert r.lines = array['Anunciado há 5 semanas em Lisboa', 'Conduzido 25 000 km', '42'],
    'the lines, empty ones left out: ' || r.lines::text;
  assert r.photos = array['https://scontent.xx.fbcdn.net/a.jpg', 'https://scontent.xx.fbcdn.net/c.jpg'],
    'https photos, once each, in order: ' || r.photos::text;
  assert r.script_version = 4, 'the version';

  -- Another account can't take it away.
  set local test.uid = '00000000-0000-0000-0000-0000000005a2';
  perform public.dismiss_shared_ad(r.id);
  set local test.uid = '00000000-0000-0000-0000-0000000005a1';
  assert (select count(*) from public.my_shared_ads()) = 1, 'still waiting';
  perform public.dismiss_shared_ad(r.id);
  assert (select count(*) from public.my_shared_ads()) = 0, 'dismissed';
end $$;

-- The same ad again replaces the waiting one; at most 10 wait.
set local role anon;
reset test.uid;
reset test.jwt;
do $$
declare
  v_key text := (select key from keys where owner = 'a1');
begin
  perform public.receive_shared_ad(v_key, '{"url": "https://x.pt/1", "title": "Primeiro"}');
  perform public.receive_shared_ad(v_key, '{"url": "https://x.pt/1", "title": "De novo"}');
  for i in 2..10 loop
    perform public.receive_shared_ad(v_key, jsonb_build_object('url', 'https://x.pt/' || i));
  end loop;
  begin
    perform public.receive_shared_ad(v_key, '{"url": "https://x.pt/11"}');
    assert false, 'an eleventh waiting ad is refused';
  exception when sqlstate '54000' then null;
  end;
end $$;

reset role;
do $$
begin
  assert (select count(*) from public.shared_ads
          where user_id = '00000000-0000-0000-0000-0000000005a1' and dismissed_at is null) = 10,
    'ten waiting';
  assert (select title from public.shared_ads where url = 'https://x.pt/1') = 'De novo',
    'the newer copy';
  -- Old ads leave the inbox; the hour's limit counts dismissed ones too.
  update public.shared_ads set dismissed_at = now()
  where user_id = '00000000-0000-0000-0000-0000000005a1';
  update public.shared_ads set received_at = now() - interval '8 days'
  where url = 'https://x.pt/2';
end $$;

set local role anon;
do $$
declare
  v_key text := (select key from keys where owner = 'a1');
begin
  -- 10 this hour (the first, dismissed, and 9 of the 10 above; the
  -- other is 8 days old now and goes): 10 more reach the limit.
  for i in 12..21 loop
    perform public.receive_shared_ad(v_key, jsonb_build_object('url', 'https://x.pt/' || i));
  end loop;
  begin
    perform public.receive_shared_ad(v_key, '{"url": "https://x.pt/22"}');
    assert false, 'the 21st in an hour is refused';
  exception when sqlstate '54000' then null;
  end;
end $$;

reset role;
do $$
begin
  assert not exists (select 1 from public.shared_ads where url = 'https://x.pt/2'),
    'an ad 7+ days old is deleted';
end $$;

-- Turning the key off stops it.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005a1';
do $$
begin
  perform public.remove_ad_import_key();
  assert public.ad_import_key_created_at() is null, 'no key';
end $$;

set local role anon;
do $$
begin
  perform public.receive_shared_ad((select key from keys where owner = 'a1'), '{"url": "https://x.pt/z"}');
  assert false, 'a removed key is refused';
exception when sqlstate '28000' then null;
end $$;

-- No API access to the tables themselves.
set local role authenticated;
do $$
begin
  assert (select count(*) from public.shared_ads) = 0, 'no rows through the API';
  assert (select count(*) from public.ad_import_keys) = 0, 'no keys through the API';
end $$;
