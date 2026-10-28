-- Photo marks and the classifier trained on them
-- (20261028190000_photo_marks.sql).
update public.motorcycles set is_active = true where slug = 'yamaha-mt-07';

insert into auth.users (id, email, created_at, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', now() - interval '2 days', false),
  ('00000000-0000-0000-0000-0000000000a2', 'second@example.com', now() - interval '1 day', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', now(), false);
insert into public.app_admins (user_id) values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, description, seller_type, images)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2020, 10000, 6000, 'Mota.', 'private', array['https://img/' || v.sid || '/1']
from public.motorcycles m
join (values ('m1'), ('m2')) v(sid) on true
where m.slug = 'yamaha-mt-07';

-- Features of 2 signed bytes: m1 photo 0 = [1, -1], photo 1 = [-1, 1];
-- m2 photo 0 = [1, -1].
insert into public.listing_photo_features (listing_id, photo, model, scores, features)
select l.id, v.photo, 'clip-test', '{"ok": 0.9}', v.features
from public.listings l
join (values ('m1', 0, '\x7f81'::bytea), ('m1', 1, '\x817f'::bytea),
             ('m2', 0, '\x7f81'::bytea)) v(sid, photo, features)
  on v.sid = l.source_listing_id;

-- An admin marks, changes and clears; only the first 3 photos.
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
declare
  v_m1 uuid := (select id from public.listings where source_listing_id = 'm1');
begin
  perform public.set_photo_mark(v_m1, 0, false);
  perform public.set_photo_mark(v_m1, 0, true);
  perform public.set_photo_mark(v_m1, 1, false);
  perform public.set_photo_mark(v_m1, 2, true);
  perform public.set_photo_mark(v_m1, 2, null);
  assert (select jsonb_agg(jsonb_build_object('photo', photo, 'problem', problem))
          from public.my_photo_marks(v_m1))
         = '[{"photo": 0, "problem": true}, {"photo": 1, "problem": false}]',
    'changed and cleared';
  begin
    perform public.set_photo_mark(v_m1, 3, true);
    assert false, 'photo 3 marked';
  exception when sqlstate '22023' then null;
  end;
end $$;

-- The second admin sees only their own marks and disagrees on photo 1.
set local test.uid = '00000000-0000-0000-0000-0000000000a2';
do $$
declare
  v_m1 uuid := (select id from public.listings where source_listing_id = 'm1');
begin
  assert not exists (select 1 from public.my_photo_marks(v_m1)), 'not the other admin''s';
  perform public.set_photo_mark(v_m1, 1, true);
end $$;

-- Not an admin: no marks, none shown.
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
declare
  v_m2 uuid := (select id from public.listings where source_listing_id = 'm2');
begin
  begin
    perform public.set_photo_mark(v_m2, 0, true);
    assert false, 'a non-admin marked';
  exception when sqlstate '42501' then null;
  end;
end $$;
reset test.uid;
reset test.jwt;

reset role;

do $$
declare
  v_m1 uuid := (select id from public.listings where source_listing_id = 'm1');
  v_m2 uuid := (select id from public.listings where source_listing_id = 'm2');
  v_key text;
begin
  -- A mark of someone no longer an admin isn't learned from.
  insert into public.photo_marks (user_id, listing_id, photo, problem)
  values ('00000000-0000-0000-0000-0000000000b1', v_m2, 0, false);

  -- Two photos; photo 1 counts as a problem (one admin said so).
  assert (select count(*) from public.photo_training_set('clip-test')) = 2, 'two photos';
  assert (select bool_and(problem) from public.photo_training_set('clip-test')),
    'both problems';
  assert (select features from public.photo_training_set('clip-test')
          where features = encode('\x817f'::bytea, 'base64')) is not null, 'base64';
  v_key := (select max(marks_key) from public.photo_training_set('clip-test'));
  assert v_key like '2@%', v_key;
  assert (select bool_and(trained_key is null) from public.photo_training_set('clip-test')),
    'nothing trained yet';

  -- Another model's: one row with its key and no photo.
  assert (select count(*) from public.photo_training_set('other')) = 1, 'one row';
  assert (select features is null and marks_key = '0@'
          from public.photo_training_set('other')), 'no marks for it';

  -- No classifier: no share, hints as before.
  assert public.photo_learned_share('clip-test', '\x7f81') is null, 'no classifier';

  -- Weights [2, 0]: [1, -1] gives sigmoid(2), [-1, 1] sigmoid(-2).
  assert public.store_photo_classifier('clip-test', array[2, 0]::double precision[], 0,
                                       2, 2, 1.0, v_key) = 2, 'both listings refreshed';
  assert abs(public.photo_learned_share('clip-test', '\x7f81') - 0.8808) < 0.001, 'sigmoid(2)';
  assert abs(public.photo_learned_share('clip-test', '\x817f') - 0.1192) < 0.001, 'sigmoid(-2)';
  assert public.photo_learned_share('clip-test', '\x7f') is null, 'another size';
  assert (select photo_hints from public.listings where id = v_m1)
         = '[{"code": "learned", "photo": 0, "p": 0.88}]', 'learned hint';
  assert (select photo_hints from public.listings where id = v_m2)
         = '[{"code": "learned", "photo": 0, "p": 0.88}]', 'also unmarked listings';
  assert (select trained_key from public.photo_training_set('clip-test') limit 1) = v_key,
    'the key it was trained on';

  -- Examined again: the classifier applies at once.
  perform public.store_photo_features('clip-test', jsonb_build_array(
    jsonb_build_object('id', v_m2, 'photos', jsonb_build_array(
      jsonb_build_object('photo', 0, 'scores', jsonb_build_object('ok', 0.9),
                         'features', encode('\x817f'::bytea, 'base64'))))));
  assert (select photo_hints from public.listings where id = v_m2) = '[]', 'now unlike';

  -- Trained again: replaced.
  perform public.store_photo_classifier('clip-test', array[-2, 0]::double precision[], 0,
                                        2, 1, null, 'x');
  assert (select count(*) from public.photo_classifiers) = 1, 'one per model';
  assert (select photo_hints from public.listings where id = v_m2)
         = '[{"code": "learned", "photo": 0, "p": 0.88}]', 'retrained';

  -- A deleted listing takes its marks.
  delete from public.listings where id = v_m1;
  assert not exists (select 1 from public.photo_marks where listing_id = v_m1), 'cascade';
end $$;

-- The app reaches the marks only through the two functions.
do $$
begin
  assert not has_table_privilege('authenticated', 'public.photo_marks', 'select'), 'marks';
  assert not has_table_privilege('authenticated', 'public.photo_classifiers', 'select'),
    'classifiers';
  assert has_function_privilege('authenticated',
    'public.set_photo_mark(uuid, integer, boolean)', 'execute'), 'marking';
  assert not has_function_privilege('anon',
    'public.set_photo_mark(uuid, integer, boolean)', 'execute'), 'not visitors';
  assert not has_function_privilege('authenticated',
    'public.photo_training_set(text)', 'execute'), 'collector only';
  assert not has_function_privilege('authenticated', 'public.store_photo_classifier('
    'text, double precision[], double precision, integer, integer, double precision, text)',
    'execute'), 'collector only';
end $$;
