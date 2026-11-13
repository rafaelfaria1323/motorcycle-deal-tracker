-- Stock photos (20261113150000_stock_photos.sql): an ad whose every photo
-- is in 5+ other ads of 3+ other bikes shows nothing of its own bike.
update public.motorcycles set is_active = true where slug = 'yamaha-mt-07';

-- s1-s6: six bikes (years and km apart) with the same two press photos;
-- s7 has them plus one of its own; r1-r6: one bike put up six times with
-- its own photos; n1: a dealer's new bike with the press photos.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type,
                             images, first_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, 6000, 'Porto', 'Vendo a minha mota em bom estado.',
       v.seller::public.seller_type, array['https://img/' || v.sid],
       now() - interval '2 days'
from public.motorcycles m
cross join (
  select 's' || g, 2015 + g, 10000 * g, 'private' from generate_series(1, 7) g
  union all
  select 'r' || g, 2019, 21000 + g * 10, 'private' from generate_series(1, 6) g
  union all
  select 'n1', 2026, 20, 'dealer'
) v(sid, year, km, seller)
where m.slug = 'yamaha-mt-07';

do $$
declare
  id_of jsonb;
begin
  select jsonb_object_agg(source_listing_id, id) into id_of from public.listings;

  for i in 1..5 loop
    perform public.store_photo_hashes(jsonb_build_array(
      jsonb_build_object('id', id_of -> ('s' || i), 'hashes',
        array['4242424242424242424', '1313131313131313131'])));
  end loop;
  assert not (select stock_photos from public.listings where source_listing_id = 's1'),
    'in four other ads: not yet a stock photo';

  perform public.store_photo_hashes(jsonb_build_array(
    jsonb_build_object('id', id_of -> 's6', 'hashes',
      array[(4242424242424242424 # 3)::text, '1313131313131313131']),
    jsonb_build_object('id', id_of -> 's7', 'hashes',
      array['4242424242424242424', '1313131313131313131', '8261657684473197624']),
    jsonb_build_object('id', id_of -> 'n1', 'hashes',
      array['4242424242424242424', '1313131313131313131'])));
  assert (select stock_photos from public.listings where source_listing_id = 's1'),
    'a later ad makes an earlier ad''s photos stock ones';
  assert (select stock_photos from public.listings where source_listing_id = 's6'),
    'a recompressed press photo is the same photo';
  assert not (select stock_photos from public.listings where source_listing_id = 's7'),
    'one photo of its own is enough';

  for i in 1..6 loop
    perform public.store_photo_hashes(jsonb_build_array(
      jsonb_build_object('id', id_of -> ('r' || i), 'hashes',
        array['555555555555555555', '-987654321987654321'])));
  end loop;
  assert not (select stock_photos from public.listings where source_listing_id = 'r1'),
    'the same bike again and again: its own photos';

  assert (select reasons @> array['stock_photos'] from public.listing_risk_scores
          where listing_id = (id_of ->> 's2')::uuid),
    'no photo of the bike itself: a risk reason';
  assert (select risk_score from public.listing_risk_scores
          where listing_id = (id_of ->> 's2')::uuid) >= 10, 'worth 10';
  assert not (select reasons @> array['stock_photos'] from public.listing_risk_scores
              where listing_id = (id_of ->> 's7')::uuid), 'not with a photo of its own';
  assert (select stock_photos from public.listings where source_listing_id = 'n1'),
    'the new bike has only press photos';
  assert not (select reasons @> array['stock_photos'] from public.listing_risk_scores
              where listing_id = (id_of ->> 'n1')::uuid),
    'normal for a dealer''s new bike';

  -- Its own photos at last: no longer stock.
  perform public.store_photo_hashes(jsonb_build_array(
    jsonb_build_object('id', id_of -> 's2', 'hashes', array['2718281828459045235'])));
  assert not (select stock_photos from public.listings where source_listing_id = 's2'),
    'replaced photos are worked out again';
end $$;

-- Only the collector.
set local role authenticated;
do $$
begin
  perform public.refresh_stock_photos('{}');
  assert false, 'the app cannot refresh them';
exception when insufficient_privilege then null;
end $$;
