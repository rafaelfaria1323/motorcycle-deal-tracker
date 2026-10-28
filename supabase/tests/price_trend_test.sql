-- Price trends per model (model_price_trend): each week's ads at the price
-- they had by the week's end; duplicates and ads under 300 € left out; the
-- adjusted median brings older or higher-mileage bikes to today's typical.
do $$
declare
  mt uuid;
  this_week date := date_trunc('week', now())::date;
  last_week date := (date_trunc('week', now()) - interval '1 week')::date;
  a uuid;
  r record;
begin
  select id into mt from public.motorcycles where slug = 'yamaha-mt-07';

  -- Five bikes of the same year and mileage, on sale since two weeks ago.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  select 'olx', 'trend' || g, 'https://x/trend' || g, mt, 'Yamaha', 'MT-07',
         2020, 20000, 6000 + g * 100,
         now() - interval '15 days', now()
  from generate_series(1, 5) g;

  -- One of them dropped from 6 100 to 5 000 this week: last week it still
  -- counts at 6 100.
  select id into a from public.listings where source_listing_id = 'trend1';
  insert into public.listing_price_history (listing_id, price, observed_at)
  values (a, 5000, date_trunc('week', now()) + interval '1 minute');
  update public.listings set price = 5000 where id = a;

  -- Left out: a duplicate and a 1 € placeholder.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at, duplicate_of)
  values ('standvirtual', 'trend-dup', 'https://x/trend-dup', mt, 'Yamaha',
          'MT-07', 2020, 20000, 99000, now() - interval '15 days', now(), a);
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'trend-1eur', 'https://x/trend-1eur', mt, 'Yamaha', 'MT-07',
          2020, 20000, 1, now() - interval '15 days', now());

  select * into r from public.model_price_trend
  where motorcycle_id = mt and week_start = last_week;
  assert r.listing_count = 5, format('last week: %s ads', r.listing_count);
  assert r.median_price = 6300, format('last week median %s', r.median_price);
  -- Every bike is the typical one: nothing to adjust.
  assert r.median_adjusted_price = r.median_price,
    format('adjusted %s, plain %s', r.median_adjusted_price, r.median_price);

  select * into r from public.model_price_trend
  where motorcycle_id = mt and week_start = this_week;
  assert r.listing_count = 5, format('this week: %s ads', r.listing_count);
  assert r.median_price = 6300, format('this week median %s', r.median_price);

  -- A week before any ad was seen has no row.
  assert not exists (
    select 1 from public.model_price_trend
    where motorcycle_id = mt and week_start < last_week - 7
  ), 'a week with no ads has a row';

  -- An older bike among them: its adjusted price is higher than what it
  -- asks (brought to the typical year), so the adjusted median rises.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'trend-old', 'https://x/trend-old', mt, 'Yamaha', 'MT-07',
          2014, 20000, 5500, now() - interval '1 day', now());
  select * into r from public.model_price_trend
  where motorcycle_id = mt and week_start = this_week;
  assert r.listing_count = 6, format('this week now: %s ads', r.listing_count);
  assert r.median_price = 6250, format('plain median %s', r.median_price);
  assert r.median_adjusted_price = 6350,
    format('adjusted median %s', r.median_adjusted_price);
end $$;

-- Readable by the app.
do $$
begin
  assert has_table_privilege('anon', 'public.model_price_trend', 'select');
  assert has_table_privilege('authenticated', 'public.model_price_trend', 'select');
end $$;
