-- N.106b (20261115130000_similar_models.sql): with too few gone ads of its
-- own, a model's time on the market comes from its similar models' ads.
do $$
declare
  mt uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  r7 uuid := (select id from public.motorcycles where slug = 'yamaha-r7');
  cb uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
  me uuid;
  ad uuid;
  r record;
begin
  assert (select similar_group from public.motorcycles where id = mt) = 'yamaha-cp2'
     and (select similar_group from public.motorcycles where id = r7) = 'yamaha-cp2',
    'the MT-07 and the R7 share a platform';
  assert (select similar_group from public.motorcycles where id = cb) = 'honda-650-four',
    'the CB650R''s group';
  assert (public.similar_motorcycle_ids(mt))[1] = mt
     and r7 = any(public.similar_motorcycle_ids(mt))
     and not cb = any(public.similar_motorcycle_ids(mt)), 'the model first, then its group';
  assert public.similar_motorcycle_ids(
           (select id from public.motorcycles where slug = 'yamaha-r1')) =
         array[(select id from public.motorcycles where slug = 'yamaha-r1')],
    'no group: only itself';

  -- This MT-07: live, first seen 10 days ago. Its model has 2 gone ads.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'sm-me', 'https://x/sm-me', mt, 'Yamaha', 'MT-07',
          2024, 8000, 7000, now() - interval '10 days', now())
  returning id into me;
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at)
  select 'olx', 'sm-mt' || g, 'https://x/sm-mt' || g, mt, 'Yamaha', 'MT-07',
         2024, 8000, 7000, 'removed', now() - interval '100 days',
         now() - interval '100 days' + make_interval(days => 20 * g)
  from generate_series(1, 2) g;

  select * into r from public.listing_time_to_sale(me);
  assert r.gone_count = 2 and r.typical_days is null and r.similar_models = '{}',
    format('too few, nothing to borrow: %s', r);
  select * into r from public.model_market_behaviour where motorcycle_id = mt;
  assert r.gone_count = 2 and r.similar_gone_count is null and r.similar_models = '{}',
    format('the view: no other model''s ads yet: %s', r);

  -- Four R7s left after 20, 40, 60 and 80 days, each with a 10 % drop at
  -- day 15; a CB650R (another group) never counts.
  for i in 1..4 loop
    insert into public.listings (source, source_listing_id, url, motorcycle_id,
                                 brand, model, year, mileage, price, status,
                                 first_seen_at, last_seen_at)
    values ('olx', 'sm-r7' || i, 'https://x/sm-r7' || i, r7, 'Yamaha', 'R7',
            2024, 8000, 8000, 'removed', now() - interval '100 days',
            now() - interval '100 days' + make_interval(days => 20 * i))
    returning id into ad;
    insert into public.listing_price_history (listing_id, price, observed_at)
    values (ad, 7200, now() - interval '85 days');
  end loop;
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at)
  values ('olx', 'sm-cb', 'https://x/sm-cb', cb, 'Honda', 'CB650R',
          2024, 8000, 7000, 'removed', now() - interval '100 days',
          now() - interval '99 days');

  select * into r from public.listing_time_to_sale(me);
  assert r.gone_count = 6 and r.similar_models = '{R7}',
    format('the group''s six: %s', r);
  -- Gone after 20, 20, 40, 40, 60, 80 days: half by day 40.
  assert r.typical_days = 40, format('typical %s', r.typical_days);
  assert r.remaining_days is not null, 'an estimate for this ad';

  select * into r from public.model_market_behaviour where motorcycle_id = mt;
  assert r.gone_count = 2, 'its own figures stay';
  assert r.similar_gone_count = 6 and r.similar_median_days_to_gone is not null
     and r.similar_models = '{R7}', format('the group''s: %s', r);
  select * into r from public.model_market_behaviour where motorcycle_id = cb;
  assert r.similar_gone_count is null and r.similar_models = '{}',
    'a group with no other model''s ads';

  -- Waiting or buying now: the MT-07's own followed ads are its 2 gone ones
  -- (one left inside days 10-40); the R7s add four drops of 10 %.
  select * into r from public.price_drop_outlook(me);
  assert r.sample = 6 and r.dropped = 4 and r.similar_models = '{R7}',
    format('the group''s outlook: %s', r);
  assert r.median_drop = 10, format('median drop %s', r.median_drop);

  -- Without the group, the model's own again.
  update public.motorcycles set similar_group = null where id = r7;
  select * into r from public.listing_time_to_sale(me);
  assert r.gone_count = 2 and r.similar_models = '{}', 'own once alone';
  select * into r from public.price_drop_outlook(me);
  assert r.sample = 2 and r.similar_models = '{}', format('own outlook: %s', r);
  update public.motorcycles set similar_group = 'yamaha-cp2' where id = r7;

  -- Five of its own: the model's, whatever the group has.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at)
  select 'olx', 'sm-mt' || g, 'https://x/sm-mt' || g, mt, 'Yamaha', 'MT-07',
         2024, 8000, 7000, 'removed', now() - interval '100 days',
         now() - interval '100 days' + make_interval(days => 20 * g)
  from generate_series(3, 5) g;
  select * into r from public.listing_time_to_sale(me);
  assert r.gone_count = 5 and r.similar_models = '{}', format('own five: %s', r);

  assert has_function_privilege('anon', 'public.listing_time_to_sale(uuid)', 'execute')
     and has_function_privilege('anon', 'public.price_drop_outlook(uuid, integer)', 'execute'),
    'still readable by visitors';
end;
$$;
