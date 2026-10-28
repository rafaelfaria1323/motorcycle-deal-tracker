-- Time to sale (10.4): Kaplan-Meier over the model's other ads, conditioned
-- on the ad's age, by price band once 5 or more of the band's ads left.
do $$
declare
  mt uuid;
  me uuid;
  r record;
begin
  -- The pure survival median, with literals. Five ads left after 10, 20,
  -- 30, 40 and 50 days: half had left by day 30.
  assert public.median_days_remaining(
    array[10, 20, 30, 40, 50]::numeric[],
    array[true, true, true, true, true], 0) = 30,
    'plain median';
  -- An ad up for 25 days: of the three that lasted that long, half left
  -- by day 40, 15 days later.
  assert public.median_days_remaining(
    array[10, 20, 30, 40, 50]::numeric[],
    array[true, true, true, true, true], 25) = 15,
    'conditioned on the age';
  -- Still-live ads count as lasting at least their age: two of four still
  -- on sale at 100 days put the median at 20 (the gone ones alone: 15).
  assert public.median_days_remaining(
    array[10, 20, 100, 100]::numeric[],
    array[true, true, false, false], 0) = 20,
    'censored ads keep the curve up';
  assert public.median_days_remaining(
    array[10, 100, 100, 100]::numeric[],
    array[true, false, false, false], 0) is null,
    'never half: no estimate';
  -- Older than every ad: no estimate.
  assert public.median_days_remaining(
    array[10, 20]::numeric[], array[true, true], 60) is null,
    'older than all';

  assert public.market_band(12) = 'below' and public.market_band(5) = 'below';
  assert public.market_band(-5) = 'above' and public.market_band(0) = 'near';
  assert public.market_band(null) is null;

  select id into mt from public.motorcycles where slug = 'yamaha-mt-07';

  -- Six ads that left, cheap ones fast (5 days), the rest slowly (60).
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, status,
                               first_seen_at, last_seen_at,
                               last_pct_below_market)
  select 'olx', 'tts' || g, 'https://x/tts' || g, mt, 'Yamaha', 'MT-07',
         2020, 20000, 6000, 'removed',
         now() - interval '100 days',
         now() - interval '100 days'
           + case when g <= 6 then interval '5 days' else interval '60 days' end,
         case when g <= 6 then 15 else 0 end
  from generate_series(1, 12) g;

  -- This ad: live for 2 days, cheap.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price,
                               first_seen_at, last_seen_at)
  values ('olx', 'tts-me', 'https://x/tts-me', mt, 'Yamaha', 'MT-07',
          2020, 20000, 5000, now() - interval '2 days', now())
  returning id into me;

  -- The score's position is kept as it is written.
  update public.listings
  set score_breakdown = '{"pct_below_market": 15}'
  where id = me;
  assert (select last_pct_below_market from public.listings where id = me) = 15,
    'position kept from the score';
  -- Clearing the score (gone) keeps the last position.
  update public.listings set score_breakdown = null where id = me;
  assert (select last_pct_below_market from public.listings where id = me) = 15,
    'position lost with the score';

  select * into r from public.listing_time_to_sale(me);
  assert r.band = 'below', format('band %s', r.band);
  assert r.gone_count = 6 and r.live_count = 0,
    format('sample %s gone, %s live', r.gone_count, r.live_count);
  assert r.days_listed = 2, format('listed %s', r.days_listed);
  assert r.typical_days = 5, format('typical %s', r.typical_days);
  assert r.remaining_days = 3, format('remaining %s', r.remaining_days);

  -- Without a position: every ad of the model (6 fast, 6 slow).
  update public.listings set last_pct_below_market = null where id = me;
  select * into r from public.listing_time_to_sale(me);
  assert r.band is null and r.gone_count = 12,
    format('model-wide %s, %s gone', r.band, r.gone_count);
  -- Up for 10 days: only the slow ones lasted; they leave on day 60.
  update public.listings set first_seen_at = now() - interval '10 days'
  where id = me;
  select * into r from public.listing_time_to_sale(me);
  assert r.remaining_days = 50, format('slow remaining %s', r.remaining_days);

  -- A band with fewer than 5 gone ads falls back to the whole model.
  update public.listings set last_pct_below_market = -20 where id = me;
  select * into r from public.listing_time_to_sale(me);
  assert r.band is null and r.gone_count = 12, 'thin band not used';

  -- A gone ad gets no remaining time; a duplicate is left out.
  update public.listings set duplicate_of = me
  where source_listing_id = 'tts12';
  update public.listings set status = 'removed' where id = me;
  select * into r from public.listing_time_to_sale(me);
  assert r.remaining_days is null, 'gone ad has a remaining time';
  assert r.gone_count = 11, format('duplicate counted: %s', r.gone_count);

  -- Fewer than 5 gone ads: no estimate at all.
  delete from public.listings
  where source_listing_id like 'tts%' and source_listing_id <> 'tts-me'
    and source_listing_id not in ('tts1', 'tts2');
  update public.listings set status = 'active' where id = me;
  select * into r from public.listing_time_to_sale(me);
  assert r.gone_count = 2 and r.typical_days is null
    and r.remaining_days is null, 'estimate from 2 ads';

  -- Readable by anonymous visitors (listings are public).
  assert has_function_privilege('anon',
    'public.listing_time_to_sale(uuid)', 'execute');
  assert not has_function_privilege('anon',
    'public.keep_market_position()', 'execute');
end;
$$;
