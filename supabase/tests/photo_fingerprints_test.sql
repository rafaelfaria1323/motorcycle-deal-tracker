-- Photo fingerprints (20261028170000_photo_fingerprints.sql): which
-- listings wait for theirs, which listings share photos (near hashes count,
-- banners in many ads don't), and what that changes: duplicates, relists
-- and the photos_reused risk reason.
update public.motorcycles set is_active = true
where slug in ('yamaha-mt-07', 'honda-cb650r');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type,
                             status, first_seen_at, last_seen_at, images, photos_read_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, 6000, 'Porto', v.descr, v.seller::public.seller_type,
       v.status::public.listing_status, v.first_seen, v.last_seen,
       array['https://img/' || v.sid || '/1', 'https://img/' || v.sid || '/2',
             'https://img/' || v.sid || '/3', 'https://img/' || v.sid || '/4'],
       v.photos_read
from public.motorcycles m
join (values
  -- the same bike on both sites, different text
  ('yamaha-mt-07', 'olx', 'd1', 2021, 12000, 'Vendo a minha mota, sempre na garagem.', 'private',
   'active', now() - interval '3 days', now(), null::timestamptz),
  ('yamaha-mt-07', 'standvirtual', 'd2', 2021, 12300, 'Excelente estado geral, revisões feitas na marca.', 'private',
   'active', now() - interval '2 days', now(), now()),
  -- a private ad with a dealer's photos of another model
  ('honda-cb650r', 'standvirtual', 's1', 2020, 20000, 'Stand com garantia e financiamento.', 'dealer',
   'active', now() - interval '5 days', now(), now()),
  ('yamaha-mt-07', 'olx', 'p1', 2019, 25000, 'Mota impecável, vendo por troca de carro.', 'private',
   'active', now() - interval '1 day', now(), null),
  -- gone, then back with other words and the same photos
  ('yamaha-mt-07', 'olx', 'g1', 2018, 30000, 'Primeira versão da mota.', 'private',
   'removed', now() - interval '40 days', now() - interval '10 days', null),
  ('yamaha-mt-07', 'olx', 'r1', 2018, 30100, 'Nova descrição sem nada em comum.', 'private',
   'active', now() - interval '4 hours', now(), null),
  -- Standvirtual before its listing page was read: waits
  ('yamaha-mt-07', 'standvirtual', 'w1', 2022, 5000, 'Por ler.', 'private',
   'active', now() - interval '1 hour', now(), null)
) v(slug, source, sid, year, km, descr, seller, status, first_seen, last_seen, photos_read)
  on v.slug = m.slug;

-- Six ads with a dealer's banner as one of their photos.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, description, seller_type, images,
                             first_seen_at)
select 'olx', 'b' || g, 'https://x/b' || g, m.id, m.brand, m.model,
       2015, 40000 + g * 5000, 4000, 'Anúncio ' || g, 'dealer', array['https://img/b' || g],
       now() - interval '30 days'
from public.motorcycles m, generate_series(1, 6) g
where m.slug = 'honda-cb650r';

reset role;

do $$
declare
  v_pending uuid[];
  id_of jsonb;
begin
  v_pending := array(select id from public.listings_missing_photo_hashes(100, 3));
  assert (select id from public.listings where source_listing_id = 'r1') = v_pending[1],
    'newest first';
  assert not (select id from public.listings where source_listing_id = 'w1') = any(v_pending),
    'Standvirtual waits for its listing page';
  assert not (select id from public.listings where source_listing_id = 'g1') = any(v_pending),
    'gone ads are not asked for';
  assert (select cardinality(images) from public.listings_missing_photo_hashes(100, 3) limit 1) = 3,
    'only the first photos';

  select jsonb_object_agg(source_listing_id, id) into id_of from public.listings;

  -- d2's photos: one recompressed (2 bits off), one other.
  assert public.store_photo_hashes(jsonb_build_array(
    jsonb_build_object('id', id_of -> 'd1', 'hashes',
      array['1234567890123456789', '-987654321987654321', '555555555555555555']),
    jsonb_build_object('id', id_of -> 'd2', 'hashes',
      array[(1234567890123456789 # 5)::text, '-987654321987654321', '3141592653589793238']),
    jsonb_build_object('id', id_of -> 's1', 'hashes',
      array['7777777777777777777', '2718281828459045235']),
    jsonb_build_object('id', id_of -> 'p1', 'hashes',
      array['7777777777777777777', '2718281828459045235', '8261657684473197624']),
    jsonb_build_object('id', id_of -> 'g1', 'hashes',
      array['100000000000000001', '200000000000000002']),
    jsonb_build_object('id', id_of -> 'r1', 'hashes',
      array['100000000000000001', '200000000000000002'])
  )) = 6, 'six listings stored';

  assert (select shared from public.listing_photo_matches
          where listing_id = (id_of ->> 'd2')::uuid and other_id = (id_of ->> 'd1')::uuid) = 2,
    'a recompressed photo is the same photo';
  assert exists (select 1 from public.listing_photo_matches
                 where listing_id = (id_of ->> 'd1')::uuid and other_id = (id_of ->> 'd2')::uuid),
    'both ways round';
  assert (select photos_hashed_at = now() from public.listings where id = (id_of ->> 'd1')::uuid),
    'marked as done';
  assert not exists (select 1 from public.listings_missing_photo_hashes(100, 3)
                     where id = (id_of ->> 'd1')::uuid),
    'not asked for again';

  -- The banner, one by one: in five other ads it proves nothing.
  for i in 1..6 loop
    perform public.store_photo_hashes(jsonb_build_array(
      jsonb_build_object('id', id_of -> ('b' || i), 'hashes', array['4242424242424242424'])));
  end loop;
  assert (select count(*) from public.listing_photo_matches
          where listing_id = (id_of ->> 'b6')::uuid) = 0,
    'a photo in five other ads is a banner';
  assert (select count(*) from public.listing_photo_matches
          where listing_id = (id_of ->> 'b1')::uuid) = 4,
    'until then, ads of one photo share it';

  -- Stored again: replaced, not added.
  perform public.store_photo_hashes(jsonb_build_array(
    jsonb_build_object('id', id_of -> 'b1', 'hashes', array['2784249659845191438'])));
  assert (select count(*) from public.listing_photo_hashes
          where listing_id = (id_of ->> 'b1')::uuid) = 1, 'one hash';
  assert not exists (select 1 from public.listing_photo_matches
                     where (id_of ->> 'b1')::uuid in (listing_id, other_id)),
    'its old matches are gone';

  -- One photo in common of three is not enough.
  perform public.store_photo_hashes(jsonb_build_array(
    jsonb_build_object('id', id_of -> 'w1', 'hashes',
      array['555555555555555555', '-8531699129511414324', '-1509457273540090022'])));
  assert not exists (select 1 from public.listing_photo_matches
                     where listing_id = (id_of ->> 'w1')::uuid),
    'one shared photo of three';
end $$;

do $$
declare
  id_of jsonb;
begin
  perform public.mark_duplicates();
  select jsonb_object_agg(source_listing_id, id) into id_of from public.listings;

  assert (select duplicate_of = (id_of ->> 'd1')::uuid and duplicate_score = 100
          from public.listings where source_listing_id = 'd2'),
    'the same photos, model, year and mileage: a duplicate whatever the text';
  assert (select relisted_from = (id_of ->> 'g1')::uuid
          from public.listings where source_listing_id = 'r1'),
    'the same photos back after the ad went: a relist';
  assert (select duplicate_of is null from public.listings where source_listing_id = 'p1'),
    'other model: not a duplicate';

  assert (select reasons @> array['photos_reused'] from public.listing_risk_scores
          where listing_id = (id_of ->> 'p1')::uuid),
    'a private ad with photos of a dealer''s other model';
  assert not (select reasons @> array['photos_reused'] from public.listing_risk_scores
              where listing_id = (id_of ->> 's1')::uuid),
    'the earlier ad had the photos first';
end $$;

-- Nobody but the collector reads or writes them.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  begin
    perform public.store_photo_hashes('[]');
    assert false, 'the app cannot store hashes';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.listing_photo_matches;
    assert false, 'the app cannot read matches';
  exception when insufficient_privilege then null;
  end;
end $$;
