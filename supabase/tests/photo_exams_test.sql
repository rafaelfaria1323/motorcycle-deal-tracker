-- Every photo of one ad examined on request (20261028210000_photo_exams.sql;
-- started at once and told when done, 20261029110000_photo_exams_now.sql).
select vault.create_secret('token', 'github_dispatch_token');

update public.motorcycles set is_active = true where slug = 'yamaha-mt-07';

insert into auth.users (id, email, created_at, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', now() - interval '2 days', false),
  ('00000000-0000-0000-0000-0000000000a9', null, now(), true);

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, description, seller_type, images,
                             first_seen_at, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2020, 10000, 6000, 'Mota.', 'private',
       array(select 'https://img/' || v.sid || '/' || i from generate_series(1, v.photos) i),
       now() - v.age, v.status::public.listing_status
from public.motorcycles m
join (values ('e1', 8, interval '1 hour', 'active'),
             ('e2', 5, interval '2 hours', 'active'),
             ('few', 3, interval '1 hour', 'active'),
             ('gone', 8, interval '1 hour', 'removed'),
             ('e3', 4, interval '1 hour', 'active'),
             ('e4', 4, interval '1 hour', 'active'),
             ('e5', 4, interval '1 hour', 'active'),
             ('e6', 4, interval '1 hour', 'active'))
  v(sid, photos, age, status) on true
where m.slug = 'yamaha-mt-07';

-- Anonymous sessions can't ask.
set local test.uid = '00000000-0000-0000-0000-0000000000a9';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  perform public.request_photo_exam(
    (select id from public.listings where source_listing_id = 'e1'));
  assert false, 'an anonymous session asked';
exception when insufficient_privilege then null;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
declare
  v_e1 uuid := (select id from public.listings where source_listing_id = 'e1');
  v_e2 uuid := (select id from public.listings where source_listing_id = 'e2');
  v_first timestamptz;
begin
  v_first := public.request_photo_exam(v_e1);
  assert v_first is not null, 'asked';
  assert (select count(*) from net.calls
          where url like '%/actions/workflows/photos.yml/dispatches') = 1,
    'a new request starts the photo step';
  assert public.request_photo_exam(v_e1) = v_first, 'asking again keeps the request';
  assert (select count(*) from net.calls) = 1, 'asking again starts nothing';
  perform public.request_photo_exam(v_e2);

  -- Only live ads with photos beyond the first 3.
  begin
    perform public.request_photo_exam(
      (select id from public.listings where source_listing_id = 'few'));
    assert false, 'three photos asked';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.request_photo_exam(
      (select id from public.listings where source_listing_id = 'gone'));
    assert false, 'a gone ad asked';
  exception when sqlstate 'P0002' then null;
  end;

  -- At most 5 new requests a day (asking again for one doesn't count).
  perform public.request_photo_exam((select id from public.listings where source_listing_id = 'e3'));
  perform public.request_photo_exam((select id from public.listings where source_listing_id = 'e4'));
  perform public.request_photo_exam((select id from public.listings where source_listing_id = 'e5'));
  assert public.request_photo_exam(v_e1) = v_first, 'a repeat past the cap';
  begin
    perform public.request_photo_exam(
      (select id from public.listings where source_listing_id = 'e6'));
    assert false, 'a sixth request';
  exception when sqlstate '54000' then null;
  end;
  assert (select count(*) from net.calls) = 5, 'one start per new request';
end $$;

-- The app can't reach the requests or the collector's functions.
do $$
begin
  assert not has_table_privilege('authenticated', 'public.photo_exam_requests', 'select'),
    'requests readable';
  assert not has_function_privilege('authenticated',
    'public.listings_awaiting_photo_exam(integer, integer)', 'execute'), 'queue callable';
  assert not has_function_privilege('authenticated',
    'public.finish_photo_exams(uuid[])', 'execute'), 'finish callable';
  assert not has_function_privilege('authenticated',
    'public.photo_exam_answers(uuid[])', 'execute'), 'answers callable';
end $$;

-- The collector: the requests in order, with up to p_photos photos; once
-- finished they leave the queue and can't be asked for again.
do $$
declare
  v_e1 uuid := (select id from public.listings where source_listing_id = 'e1');
  v_e2 uuid := (select id from public.listings where source_listing_id = 'e2');
begin
  update public.listings set photo_exam_requested_at = now() - interval '1 hour'
  where id = v_e2;

  -- The rest were asked at the same moment (now() is fixed here).
  assert (select id from public.listings_awaiting_photo_exam(1, 6)) = v_e2,
    'oldest request first';
  assert (select count(*) from public.listings_awaiting_photo_exam(10, 6)) = 5,
    'every waiting request';
  assert (select cardinality(images) from public.listings_awaiting_photo_exam(10, 6)
          where id = v_e1) = 6, 'up to p_photos photos';

  assert not exists (select 1 from public.photo_exam_answers(array[v_e1])),
    'no answer before it is done';
  update public.listings
  set photo_hints = '[{"code": "rust", "photo": 4, "p": 0.6},
                      {"code": "rust", "photo": 5, "p": 0.7},
                      {"code": "scratches", "photo": 1, "p": 0.5}]'
  where id = v_e1;
  assert public.finish_photo_exams(array[v_e1]) = 1, 'finished';
  assert (select count(*) from public.photo_exam_answers(array[v_e1, v_e2])) = 1,
    'only finished listings, each asker';
  assert (select (user_id, brand, model, year, hints)
                 = ('00000000-0000-0000-0000-0000000000a1'::uuid, 'Yamaha', 'MT-07', 2020, 2)
          from public.photo_exam_answers(array[v_e1])), 'the asker, the bike, kinds of hint';
  assert public.finish_photo_exams(array[v_e1]) = 0, 'finished once';
  assert not exists (select 1 from public.listings_awaiting_photo_exam(10, 30)
                     where id = v_e1), 'left the queue';
  assert (select photos_examined_all_at is not null and photo_exam_requested_at is null
          from public.listings where id = v_e1), 'marked done';
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  assert public.request_photo_exam(
    (select id from public.listings where source_listing_id = 'e1')) is null,
    'already examined';
end $$;
