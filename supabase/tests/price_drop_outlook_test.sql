-- Waiting or buying now (N.83): what the model's other ads did in the
-- 30 days after they were as old as this one.
do $$
declare
  mt uuid;
  me uuid;
  ad uuid;
  r record;
begin
  select id into mt from public.motorcycles where slug = 'yamaha-mt-07';

  -- This ad: first seen 10 days ago.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'pdo-me', 'https://x/pdo-me', mt, 'Yamaha', 'MT-07',
          2020, 20000, 6000, now() - interval '10 days', now())
  returning id into me;

  -- Four ads first seen 100 days ago, at 6 000 €, still for sale; two
  -- dropped 10 % at day 20 (inside days 10-40), one at day 50 (after the
  -- window), one dropped to a placeholder "1 €" (no drop).
  for i in 1..4 loop
    insert into public.listings (source, source_listing_id, url,
                                 motorcycle_id, brand, model, year, mileage,
                                 price, first_seen_at, last_seen_at)
    values ('olx', 'pdo-live' || i, 'https://x/pdo-live' || i, mt, 'Yamaha',
            'MT-07', 2020, 20000, 6000, now() - interval '100 days', now())
    returning id into ad;
    insert into public.listing_price_history (listing_id, price, observed_at)
    values (ad,
            case when i = 4 then 1 else 5400 end,
            now() - interval '100 days'
              + case when i = 3 then interval '50 days'
                     else interval '20 days' end);
  end loop;

  -- Gone ads: one left at day 25 (inside), one at day 60 (after: stayed),
  -- one at day 5 (before this ad's age: not counted).
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at)
  select 'olx', 'pdo-gone' || g, 'https://x/pdo-gone' || g, mt, 'Yamaha',
         'MT-07', 2020, 20000, 6000, 'removed',
         now() - interval '100 days',
         now() - interval '100 days' + make_interval(days => g)
  from unnest(array[25, 60, 5]) g;

  -- A recent live ad (first seen 20 days ago): not followed for the whole
  -- window yet, not counted.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'pdo-new', 'https://x/pdo-new', mt, 'Yamaha', 'MT-07',
          2020, 20000, 6000, now() - interval '20 days', now());

  -- A duplicate: not counted.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at, duplicate_of)
  values ('olx', 'pdo-dup', 'https://x/pdo-dup', mt, 'Yamaha', 'MT-07',
          2020, 20000, 6000, now() - interval '100 days', now(), me);

  select * into r from public.price_drop_outlook(me);
  assert r.sample = 6, format('sample %s', r.sample);
  assert r.dropped = 2, format('dropped %s', r.dropped);
  assert r.gone = 1, format('gone %s', r.gone);
  assert r.unchanged = 3, format('unchanged %s', r.unchanged);
  assert r.median_drop = 10, format('median drop %s', r.median_drop);

  -- A shorter window (5 days: days 10-15) sees no drop and no exit.
  select * into r from public.price_drop_outlook(me, 5);
  assert r.dropped = 0 and r.gone = 0, 'nothing in 5 days';
  assert r.median_drop is null, 'no drops, no median';

  -- A gone ad one run saw is left out (N.93): this ad 10 minutes old,
  -- the other gone after 20 minutes would otherwise count as leaving.
  update public.listings set first_seen_at = now() - interval '10 minutes'
  where id = me;
  select * into r from public.price_drop_outlook(me);
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at)
  values ('olx', 'pdo-once', 'https://x/pdo-once', mt, 'Yamaha', 'MT-07',
          2020, 20000, 6000, 'removed', now() - interval '100 days',
          now() - interval '100 days' + interval '20 minutes');
  assert (select (o.sample, o.gone) = (r.sample, r.gone)
          from public.price_drop_outlook(me) o), 'seen once counted';
  update public.listings
  set last_seen_at = now() - interval '100 days' + interval '2 hours'
  where source_listing_id = 'pdo-once';
  assert (select o.gone = r.gone + 1 from public.price_drop_outlook(me) o),
    'seen by two runs: it left';

  -- A gone ad, or one without a real price, gets nothing.
  update public.listings set price = 1 where id = me;
  assert (select sample from public.price_drop_outlook(me)) = 0,
    'placeholder price';
  update public.listings set price = 6000, status = 'removed' where id = me;
  assert (select sample from public.price_drop_outlook(me)) = 0, 'gone ad';
end;
$$;
