-- Alerts for a saved search: only events after it was created, price drops
-- of at least 1 %, and never twice for the same event.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1');

insert into public.saved_searches (id, user_id, motorcycle_id, created_at)
select '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
       id, now() - interval '1 day'
from public.motorcycles where slug = 'yamaha-mt-07';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price, first_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000, v.seen
from public.motorcycles m,
     (values ('new', now()), ('old', now() - interval '2 days')) v(sid, seen)
where m.slug = 'yamaha-mt-07';
-- now() is the same all through a transaction: date the first prices
-- earlier so the drops below come after them.
update public.listing_price_history set observed_at = now() - interval '1 hour';

do $$
declare
  u constant uuid := '00000000-0000-0000-0000-0000000000a1';
begin
  perform public.generate_alerts();
  assert (select count(*) from public.alerts where user_id = u and type = 'new_listing') = 1,
    'one new-listing alert: the listing seen before the search is not new';
  assert (select l.source_listing_id from public.alerts a join public.listings l on l.id = a.listing_id
          where a.user_id = u and a.type = 'new_listing') = 'new',
    'the alert is for the new listing';

  -- 7000 -> 6950 is 0.7 %: too small. 6950 -> 6500 is 6.5 %.
  perform public.apply_price_updates('olx', '{"new": 6950, "old": 6500}');
  perform public.generate_alerts();
  assert (select count(*) from public.alerts where type = 'price_reduction') = 1,
    'only the drop of 1 % or more';
  assert (select (old_price, new_price) = (7000::numeric, 6500::numeric)
          from public.alerts where type = 'price_reduction'),
    'the alert carries both prices';

  perform public.generate_alerts();
  assert (select count(*) from public.alerts where user_id = u) = 2, 'running again adds nothing';
end $$;
