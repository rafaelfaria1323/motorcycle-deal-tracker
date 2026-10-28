-- Photo hints (20261028180000_photo_hints.sql): which listings wait for
-- the image model, what is stored and which codes become hints.
update public.motorcycles set is_active = true where slug = 'yamaha-mt-07';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, description, seller_type, images,
                             first_seen_at, photos_hashed_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2020, 10000, 6000, 'Mota.', 'private',
       array['https://img/' || v.sid || '/1', 'https://img/' || v.sid || '/2'],
       v.first_seen, v.hashed
from public.motorcycles m
join (values
  ('h1', now() - interval '1 day', now() - interval '1 hour'),   -- fingerprinted (P.1)
  ('n1', now() - interval '2 days', null::timestamptz)          -- not yet
) v(sid, first_seen, hashed) on true
where m.slug = 'yamaha-mt-07';

reset role;

do $$
declare
  v_h1 uuid := (select id from public.listings where source_listing_id = 'h1');
  v_n1 uuid := (select id from public.listings where source_listing_id = 'n1');
  v_hints jsonb;
begin
  assert array(select id from public.listings_missing_photo_checks(100, 3, false)) = array[v_n1],
    'without the model: only the fingerprints missing';
  assert array(select id from public.listings_missing_photo_checks(100, 3, true)) = array[v_n1, v_h1],
    'with the model: also the ones fingerprinted before, after the others';

  -- The best photo per code, likeliest first; ok/other and weak shares
  -- never hint.
  v_hints := public.photo_hint_codes(jsonb_build_array(
    jsonb_build_object('photo', 0, 'scores', jsonb_build_object(
      'fallen', 0.55, 'scratches', 0.2, 'ok', 0.25)),
    jsonb_build_object('photo', 2, 'scores', jsonb_build_object(
      'fallen', 0.8, 'rust', 0.1, 'other', 0.1)),
    jsonb_build_object('photo', 1, 'scores', jsonb_build_object(
      'ok', 0.9, 'scratches', 0.5))
  ));
  assert v_hints = '[{"code": "fallen", "photo": 2, "p": 0.80},
                     {"code": "scratches", "photo": 1, "p": 0.50}]'::jsonb,
    format('hints: %s', v_hints);
  assert public.photo_hint_codes('[]') = '[]' and public.photo_hint_codes(null) = '[]',
    'nothing to hint';

  assert public.store_photo_features('clip-test', jsonb_build_array(
    jsonb_build_object('id', v_h1, 'photos', jsonb_build_array(
      jsonb_build_object('photo', 0, 'scores', jsonb_build_object('crashed', 0.7, 'ok', 0.3),
                         'features', 'AQL/'),
      jsonb_build_object('photo', 1, 'scores', jsonb_build_object('ok', 1.0),
                         'features', 'AAA='))),
    jsonb_build_object('id', v_n1, 'photos', '[]'::jsonb)
  )) = 2, 'both stored';

  assert (select photo_hints from public.listings where id = v_h1)
         = '[{"code": "crashed", "photo": 0, "p": 0.70}]', 'the hint';
  assert (select photo_hints = '[]' and photos_examined_at is not null
          from public.listings where id = v_n1), 'no photo examined: done, no hints';
  assert (select features from public.listing_photo_features
          where listing_id = v_h1 and photo = 0) = '\x0102ff'::bytea, 'the embedding';
  assert (select model from public.listing_photo_features limit 1) = 'clip-test', 'the model';

  -- Examined again: what was stored before goes.
  perform public.store_photo_features('clip-test', jsonb_build_array(
    jsonb_build_object('id', v_h1, 'photos', jsonb_build_array(
      jsonb_build_object('photo', 1, 'scores', jsonb_build_object('ok', 1.0), 'features', 'AA=='))
  )));
  assert (select count(*) from public.listing_photo_features where listing_id = v_h1) = 1,
    'replaced';
  assert (select photo_hints from public.listings where id = v_h1) = '[]', 'hint gone';
  assert not exists (select 1 from public.listings_missing_photo_checks(100, 3, true)
                     where id = v_h1), 'examined: not asked for again';
end;
$$;

-- Neither the app nor visitors reach the features or the functions.
do $$
begin
  assert not has_table_privilege('authenticated', 'public.listing_photo_features', 'select'),
    'no API access to the features';
  assert not has_function_privilege('authenticated',
    'public.store_photo_features(text, jsonb)', 'execute'), 'collector only';
  assert not has_function_privilege('anon',
    'public.listings_missing_photo_checks(integer, integer, boolean)', 'execute'),
    'collector only';
end;
$$;
