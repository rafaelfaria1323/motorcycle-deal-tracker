-- A stored ad takes the seller's later edits (20261110120000_listing_facts.sql).
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, year, mileage, variant, description, location)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7300,
       2025, v.km, 'MT-07 2025', v.description, 'Mateus'
from public.motorcycles m,
     (values ('edited', 6500, 'Como nova.'),
             ('same', 6500, 'Como nova.'),
             ('text', null::integer, 'Mota com 6.500 km.'),
             ('phone', 6500, 'Ligue 912 345 678 para ver.')) v(sid, km, description)
where m.slug = 'yamaha-mt-07';

do $$
declare
  n integer;
begin
  assert (select mileage = 6500 and mileage_from_text
          from public.listings where source_listing_id = 'text');

  n := public.apply_listing_facts('olx', jsonb_build_array(
    jsonb_build_object('source_listing_id', 'edited', 'year', 2024,
      'mileage', 8500, 'variant', 'MT-07 35kW A2', 'description',
      'Com alguns riscos.', 'location', 'Vila Real'),
    -- Nothing new, and facts the site doesn't give.
    jsonb_build_object('source_listing_id', 'same', 'year', 2025,
      'mileage', 6500, 'variant', null, 'description', null, 'location', null),
    -- The site's field now holds the mileage.
    jsonb_build_object('source_listing_id', 'text', 'year', null,
      'mileage', 8500, 'variant', null, 'description', null, 'location', null),
    -- The same text as stored, before the phone number is removed.
    jsonb_build_object('source_listing_id', 'phone', 'year', 2025,
      'mileage', 6500, 'variant', 'MT-07 2025', 'description',
      'Ligue 912 345 678 para ver.', 'location', 'Mateus'),
    jsonb_build_object('source_listing_id', 'unknown', 'mileage', 1)));
  assert n = 2, format('2 listings changed, got %s', n);

  assert (select year = 2024 and mileage = 8500 and not mileage_from_text
                 and variant = 'MT-07 35kW A2'
                 and description = 'Com alguns riscos.'
                 and location = 'Vila Real'
                 and text_signals is not null
          from public.listings where source_listing_id = 'edited'),
    'the edited ad holds what the site says now';
  assert (select public.description_signals(variant, description) = text_signals
          from public.listings where source_listing_id = 'edited'),
    'the text signals follow the new text';
  assert (select year = 2025 and mileage = 6500 and variant = 'MT-07 2025'
                 and description = 'Como nova.' and location = 'Mateus'
          from public.listings where source_listing_id = 'same'),
    'absent facts erase nothing';
  assert (select mileage = 8500 and not mileage_from_text
          from public.listings where source_listing_id = 'text'),
    'the site''s mileage replaces the one read from the text';
  assert (select description !~ '912' from public.listings
          where source_listing_id = 'phone'),
    'no phone number comes back';

  -- Another source's ad with the same id is left alone.
  assert public.apply_listing_facts('standvirtual', jsonb_build_array(
    jsonb_build_object('source_listing_id', 'same', 'mileage', 1))) = 0;

  -- Only the collector may call it.
  assert not has_function_privilege('authenticated',
    'public.apply_listing_facts(text, jsonb)', 'execute');
  assert not has_function_privilege('anon',
    'public.apply_listing_facts(text, jsonb)', 'execute');
end $$;

-- Photos follow the seller's edits (20261111150000_listing_photos_follow.sql).
update public.listings
set images = array['a', 'b', 'c', 'd'], photos_hashed_at = now(),
    photos_examined_at = now(), photos_examined_all_at = now()
where source = 'olx' and source_listing_id in ('edited', 'same', 'text');

insert into auth.users (id) values ('00000000-0000-0000-0000-00000000f0f0');
insert into public.photo_marks (user_id, listing_id, photo, problem)
select '00000000-0000-0000-0000-00000000f0f0', id, 0, true
from public.listings
where source = 'olx' and source_listing_id in ('edited', 'same', 'text');

do $$
declare
  n integer;
begin
  n := public.apply_listing_facts('olx', jsonb_build_array(
    -- The first photo replaced.
    jsonb_build_object('source_listing_id', 'edited',
      'images', jsonb_build_array('z', 'b', 'c', 'd')),
    -- Only a later photo added.
    jsonb_build_object('source_listing_id', 'same',
      'images', jsonb_build_array('a', 'b', 'c', 'd', 'e')),
    -- The same photos, and a site that sends none.
    jsonb_build_object('source_listing_id', 'text',
      'images', jsonb_build_array('a', 'b', 'c', 'd')),
    jsonb_build_object('source_listing_id', 'phone',
      'images', jsonb_build_array())));
  assert n = 2, format('2 listings got new photos, got %s', n);

  assert (select images = array['z', 'b', 'c', 'd'] and photos_hashed_at is null
                 and photos_examined_at is null
                 and photos_examined_all_at is null
          from public.listings where source_listing_id = 'edited'),
    'new first photos are fingerprinted and examined again';
  assert not exists (
    select 1 from public.photo_marks k join public.listings l on l.id = k.listing_id
    where l.source_listing_id = 'edited'), 'marks on replaced photos go';

  assert (select cardinality(images) = 5 and photos_hashed_at is not null
                 and photos_examined_at is not null
                 and photos_examined_all_at is null
          from public.listings where source_listing_id = 'same'),
    'a later photo added keeps the first three''s checks';
  assert (select count(*) = 2 from public.photo_marks),
    'marks on unchanged photos stay';

  assert (select photos_examined_all_at is not null
          from public.listings where source_listing_id = 'text'),
    'the same photos change nothing';
end
$$;

