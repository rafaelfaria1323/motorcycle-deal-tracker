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
