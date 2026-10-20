-- The import steps after save: rematch, search keys, listing dates, the
-- price before a drop, and switching a model off and on from the app.
insert into public.listings (source, source_listing_id, url, brand, model, price, motorcycle_id,
                             search_key, published_at, site_refreshed_at, price_before_drop, status)
values ('olx', 'i1', 'https://x/i1', 'Yamaha', 'MT-07', 6000,
        (select id from public.motorcycles where slug = 'yamaha-mt-07'),
        'A', '2026-10-01', '2026-10-10', null, 'active'),
       ('olx', 'i2', 'https://x/i2', 'Honda', 'CB650R', 7000,
        (select id from public.motorcycles where slug = 'honda-cb650r'),
        'B', '2026-10-05', '2026-10-05', 7500, 'active'),
       ('olx', 'i3', 'https://x/i3', 'honda', 'cb650r', 7200, null,
        null, null, null, null, 'removed'),
       ('standvirtual', 'i1', 'https://y/i1', 'Yamaha', 'MT-07', 6000,
        (select id from public.motorcycles where slug = 'yamaha-mt-07'),
        'A', '2026-10-01', '2026-10-10', null, 'active');

do $$
declare
  n int;
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  tracer uuid := (select id from public.motorcycles where slug = 'yamaha-tracer-7');
  cb650r uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
begin
  assert tracer is not null and mt07 is not null and cb650r is not null, 'catalog slugs exist';

  -- rematch_listings: only listings whose model changes, brand and model follow.
  n := public.rematch_listings('olx', jsonb_build_object(
    'i1', jsonb_build_object('motorcycle_id', tracer, 'brand', 'Yamaha', 'model', 'Tracer 7'),
    'i2', jsonb_build_object('motorcycle_id', cb650r, 'brand', 'X', 'model', 'Y'),
    'zz', jsonb_build_object('motorcycle_id', tracer, 'brand', 'Yamaha', 'model', 'Tracer 7')));
  assert n = 1, format('one listing changes model, got %s', n);
  assert (select motorcycle_id = tracer and model = 'Tracer 7'
          from public.listings where source = 'olx' and source_listing_id = 'i1'),
    'i1 moves to the Tracer 7 with its name';
  assert (select model from public.listings where source = 'olx' and source_listing_id = 'i2') = 'CB650R',
    'a listing keeping its model is not touched';
  assert (select motorcycle_id from public.listings where source = 'standvirtual') = mt07,
    'the other site''s listing with the same id keeps its model';

  n := public.rematch_listings('olx', jsonb_build_object(
    'i1', jsonb_build_object('motorcycle_id', '', 'brand', 'Yamaha', 'model', 'Tracer')));
  assert n = 1 and (select motorcycle_id is null from public.listings
                    where source = 'olx' and source_listing_id = 'i1'),
    'an empty model id unmatches';

  -- set_search_keys: counts only real changes.
  n := public.set_search_keys('olx', '{"i1": "A", "i2": "C", "i3": "C", "zz": "C"}');
  assert n = 2, format('two keys change, got %s', n);
  assert (select search_key from public.listings where source = 'olx' and source_listing_id = 'i3') = 'C',
    'a listing without a key gets one';
  assert (select search_key from public.listings where source = 'standvirtual') = 'A',
    'the other site keeps its key';

  -- apply_listing_dates: earliest publication, latest renewal, nulls change nothing.
  n := public.apply_listing_dates('olx', '{
    "i1": {"published_at": "2026-09-20T00:00:00Z", "site_refreshed_at": "2026-10-08T00:00:00Z"},
    "i2": {"published_at": "2026-10-09T00:00:00Z", "site_refreshed_at": "2026-10-12T00:00:00Z"},
    "i3": {"published_at": null, "site_refreshed_at": null}}');
  assert n = 2, format('two listings get new dates, got %s', n);
  assert (select published_at = '2026-09-20T00:00:00Z' and site_refreshed_at = '2026-10-10'
          from public.listings where source = 'olx' and source_listing_id = 'i1'),
    'i1: earlier publication taken, older renewal ignored';
  assert (select published_at = '2026-10-05' and site_refreshed_at = '2026-10-12T00:00:00Z'
          from public.listings where source = 'olx' and source_listing_id = 'i2'),
    'i2: later publication ignored, newer renewal taken';
  assert (select published_at is null and site_refreshed_at is null
          from public.listings where source = 'olx' and source_listing_id = 'i3'),
    'missing dates stay missing';
  assert (select published_at from public.listings where source = 'standvirtual') = '2026-10-01',
    'the other site''s dates stay';

  -- apply_prices_before_drop: the highest seen, nulls ignored.
  n := public.apply_prices_before_drop('olx', '{"i1": 6500, "i2": 7400, "i3": null}');
  assert n = 1, format('one price before drop stored, got %s', n);
  assert (select price_before_drop from public.listings where source = 'olx' and source_listing_id = 'i1') = 6500,
    'i1 gets its first price before the drop';
  assert (select price_before_drop from public.listings where source = 'olx' and source_listing_id = 'i2') = 7500,
    'a lower price before the drop never replaces a higher one';
  n := public.apply_prices_before_drop('olx', '{"i2": 7900}');
  assert n = 1 and (select price_before_drop from public.listings
                    where source = 'olx' and source_listing_id = 'i2') = 7900,
    'a higher one does';
end $$;

-- Switching a model off unmatches its listings; on again matches them back
-- by their stored brand and model (any case, removed ones included).
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';
select public.set_model_tracked((select id from public.motorcycles where slug = 'honda-cb650r'), false);
reset role;

do $$
begin
  assert (select count(*) from public.listings where motorcycle_id =
          (select id from public.motorcycles where slug = 'honda-cb650r')) = 0,
    'off: no listing keeps the model';
  assert (select motorcycle_id from public.listings where source = 'standvirtual') is not null,
    'other models keep theirs';
  assert not (select is_active from public.motorcycles where slug = 'honda-cb650r'), 'off: not tracked';
end $$;

set local role authenticated;
select public.set_model_tracked((select id from public.motorcycles where slug = 'honda-cb650r'), true);
reset role;

do $$
declare
  cb650r uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
begin
  assert (select motorcycle_id from public.listings where source = 'olx' and source_listing_id = 'i2') = cb650r,
    'on: the live listing is matched again';
  assert (select motorcycle_id from public.listings where source = 'olx' and source_listing_id = 'i3') = cb650r,
    'on: the removed one in lower case too';
  assert (select motorcycle_id from public.listings where source = 'olx' and source_listing_id = 'i1') is null,
    'on: a listing of another model stays unmatched';
end $$;
