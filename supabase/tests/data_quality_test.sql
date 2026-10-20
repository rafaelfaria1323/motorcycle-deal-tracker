-- "Qualidade dos dados": live listings only; when the site's listings were
-- last seen; prices that moved by half or more in one step in 30 days.
insert into public.listings (id, source, source_listing_id, url, brand, model, status, price, last_seen_at)
values ('00000000-0000-0000-0000-000000000001', 'olx', 'q1', 'u1', 'Yamaha', 'MT-07', 'active', 750, now() - interval '2 hours'),
       ('00000000-0000-0000-0000-000000000002', 'olx', 'q2', 'u2', 'Yamaha', 'MT-07', 'price_changed', 7000, now() - interval '5 hours'),
       ('00000000-0000-0000-0000-000000000003', 'olx', 'q3', 'u3', 'Yamaha', 'MT-07', 'active', 9000, now() - interval '1 hour'),
       ('00000000-0000-0000-0000-000000000004', 'olx', 'q4', 'u4', 'Yamaha', 'MT-07', 'removed', 100, now()),
       ('00000000-0000-0000-0000-000000000005', 'olx', 'q5', 'u5', 'Yamaha', 'MT-07', 'active', 4000, now() - interval '1 hour');
delete from public.listing_price_history;
insert into public.listing_price_history (listing_id, price, observed_at) values
  ('00000000-0000-0000-0000-000000000001', 7500, now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000000001', 750, now() - interval '1 day'),    -- misread: counted
  ('00000000-0000-0000-0000-000000000002', 7500, now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000000002', 7000, now() - interval '1 day'),   -- normal drop
  ('00000000-0000-0000-0000-000000000003', 6000, now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000000003', 9000, now() - interval '1 day'),   -- +50 %: counted
  ('00000000-0000-0000-0000-000000000005', 9000, now() - interval '60 days'),
  ('00000000-0000-0000-0000-000000000005', 4000, now() - interval '40 days'), -- too long ago
  ('00000000-0000-0000-0000-000000000004', 1000, now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000004', 100, now() - interval '1 day');    -- not live

do $$
declare
  q public.source_data_quality;
begin
  select * into q from public.source_data_quality where source = 'olx';
  assert q.live_count = 4, format('live listings: %s', q.live_count);
  assert q.sharp_price_changes = 2, format('sharp changes: %s', q.sharp_price_changes);
  assert q.last_seen_at = now() - interval '1 hour', 'latest live listing seen, removed ones left out';
end $$;
