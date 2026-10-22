-- Telegram notifications: pending alerts of real accounts only, oldest first,
-- and each marked sent once.
insert into auth.users (id, is_anonymous)
values ('00000000-0000-0000-0000-0000000000a1', false),
       ('00000000-0000-0000-0000-0000000000a2', true);

insert into public.listings (source, source_listing_id, url, brand, model, price, year, mileage, location)
values ('olx', 'n1', 'https://x/n1', 'Yamaha', 'MT-07', 6500, 2021, 12000, 'Porto');

insert into public.alerts (user_id, listing_id, type, old_price, new_price, created_at)
select u, l.id, t::public.alert_type, op, np, c
from public.listings l,
     (values ('00000000-0000-0000-0000-0000000000a1'::uuid, 'price_reduction', 7000, 6500, now() - interval '1 hour'),
             ('00000000-0000-0000-0000-0000000000a1'::uuid, 'new_listing', null, null, now() - interval '2 hours'),
             ('00000000-0000-0000-0000-0000000000a2'::uuid, 'new_listing', null, null, now() - interval '3 hours'))
       v(u, t, op, np, c)
where l.source_listing_id = 'n1';

do $$
declare
  ids uuid[];
  n int;
begin
  select array_agg(alert_id order by ord) into ids
  from public.pending_notifications() with ordinality p(alert_id, user_id, listing_id, type, old_price,
                                                       new_price, brand, model, year, mileage, price,
                                                       deal_score, location, url, to_telegram,
                                                       created_at, my_colour, ord);
  assert cardinality(ids) = 2, 'the anonymous session''s alert is not sent';
  assert (select type from public.alerts where id = ids[1]) = 'new_listing', 'oldest first';
  assert (select p.old_price = 7000 and p.new_price = 6500 and p.brand = 'Yamaha' and p.mileage = 12000
                 and p.location = 'Porto' and p.url = 'https://x/n1'
                 and p.user_id = '00000000-0000-0000-0000-0000000000a1'
                 and p.listing_id = (select id from public.listings where source_listing_id = 'n1')
          from public.pending_notifications() p where p.type = 'price_reduction'),
    'the message has the listing and the prices';
  assert (select count(*) from public.pending_notifications(1)) = 1, 'the limit holds';
  assert (select bool_and(p.created_at = a.created_at)
          from public.pending_notifications() p
          join public.alerts a on a.id = p.alert_id), 'each alert says when it was made';

  n := public.mark_alerts_notified(ids);
  assert n = 2, format('two marked, got %s', n);
  assert (select count(*) from public.pending_notifications()) = 0, 'nothing left to send';
  n := public.mark_alerts_notified(ids);
  assert n = 0, 'never marked twice';
end $$;
