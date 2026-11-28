-- How fast good deals go (N.138): found after, up for, within a day, seen
-- once and first alert, per Deal Score band.

-- Day 0 is ten days ago, at midnight Lisbon time; ads are placed in hours
-- from it.
create temporary table speed_ads (sid text, score integer, status text,
                                  published numeric, found numeric, seen numeric);
insert into speed_ads values
  ('sp-fast', 85, 'removed', 12, 13, 18),      -- found after 1 h, gone after 6 h
  ('sp-slow', 90, 'removed', 12, 14, 134),     -- found after 2 h, up 122 h
  ('sp-night', 82, 'active', 2, 8, 230),       -- published at 02:00, found at 08:00
  ('sp-once', 88, 'removed', 12, 12.5, 12.6),  -- one run saw it
  ('sp-old', 95, 'removed', 0, 120, 130),      -- found 5 days after: left out
  ('sp-mid', 70, 'active', 12, 16, 230);       -- the 60-79 band

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, seller_type, last_deal_score,
                             published_at, first_seen_at, last_seen_at)
select 'olx', s.sid, 'https://x/' || s.sid, m.id, m.brand, m.model, 2020, 20000, 6000,
       s.status::public.listing_status, 'private', s.score,
       d.day0 + make_interval(secs => s.published * 3600),
       d.day0 + make_interval(secs => s.found * 3600),
       d.day0 + make_interval(secs => s.seen * 3600)
from public.motorcycles m, speed_ads s,
     (select (date_trunc('day', now() at time zone 'Europe/Lisbon') - interval '10 days')
               at time zone 'Europe/Lisbon' as day0) d
where m.slug = 'yamaha-mt-07';

-- The first alert on sp-fast, 6 minutes after it was found (1.1 h after it
-- went up); a removal alert never counts.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000005d1');
insert into public.alerts (user_id, listing_id, type, new_price, created_at)
select '00000000-0000-0000-0000-0000000005d1', l.id, v.type::public.alert_type, 6000,
       l.first_seen_at + v.after
from public.listings l,
     (values ('new_listing', interval '6 minutes'),
             ('excellent_opportunity', interval '2 hours')) v(type, after)
where l.source_listing_id = 'sp-fast';
insert into public.alerts (user_id, listing_id, type, new_price, created_at)
select '00000000-0000-0000-0000-0000000005d1', l.id, 'listing_removed', 6000, l.first_seen_at
from public.listings l
where l.source_listing_id = 'sp-slow';

do $$
declare
  r record;
begin
  select * into r from public.score_check_speed(60, '-infinity') where band = '80-100';
  assert r.ads = 4, format('four good deals (not the one found late): %s', r);
  assert r.found_hours = 1.5, format('found after 0.5, 1, 2, 6 h: %s', r.found_hours);
  assert r.found_p90_hours = 4.8, format('the slowest tenth: %s', r.found_p90_hours);
  assert r.night_ads = 1 and r.night_found_hours = 6.0,
    format('published at night: %s', r);
  assert r.sales = 2 and r.sales_within_day = 1, format('two sales, one within a day: %s', r);
  assert r.sale_hours = 64.0, format('up 6 and 122 h: %s', r.sale_hours);
  assert r.seen_once = 1, format('one seen once: %s', r.seen_once);
  assert r.alerted = 1 and r.alert_hours = 1.1, format('the first alert: %s', r);

  select * into r from public.score_check_speed(60, '-infinity') where band = '60-79';
  assert r.ads = 1 and r.found_hours = 4.0 and r.sales = 0 and r.sale_hours is null
     and r.night_ads = 0 and r.night_found_hours is null and r.alerted = 0,
    format('the middle band: %s', r);
  assert not exists (select 1 from public.score_check_speed(60, '-infinity')
                     where band = '0-59'), 'no band without ads';

  -- Only ads found since p_since, and in the last p_days days.
  assert not exists (select 1 from public.score_check_speed(60, now() - interval '5 days')),
    'found before p_since';
  assert not exists (select 1 from public.score_check_speed(5, '-infinity')),
    'found more than p_days ago';
end $$;

-- An ad found today has had no day yet.
update public.listings set first_seen_at = now() - interval '2 hours',
                           published_at = now() - interval '3 hours'
where source_listing_id = 'sp-mid';
do $$
begin
  assert not exists (select 1 from public.score_check_speed(60, '-infinity')
                     where band = '60-79'), 'a day to go';
end $$;

set local role authenticated;
do $$
begin
  perform public.score_check_speed();
  assert false, 'the app read the check';
exception when insufficient_privilege then null;
end $$;
reset role;
