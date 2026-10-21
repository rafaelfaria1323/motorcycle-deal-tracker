-- A bike that comes back in a new ad alerts the people who followed the
-- earlier ad (favourite or saved-search alert), once, with the old price;
-- not others, not old relists, not inactive searches.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'),  -- favourite
                                   ('00000000-0000-0000-0000-0000000000a2'),  -- search alert
                                   ('00000000-0000-0000-0000-0000000000a3'),  -- both
                                   ('00000000-0000-0000-0000-0000000000a4'),  -- inactive search
                                   ('00000000-0000-0000-0000-0000000000a5');
-- Every account here follows every collected model.
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year from auth.users u cross join public.motorcycles m
where m.is_active;  -- nothing

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, status, first_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.price,
       v.status::public.listing_status, now() - v.age
from public.motorcycles m,
     (values ('gone', 7000, 'removed', interval '60 days'),
             ('back', 6800, 'active',  interval '1 day'),
             ('old_gone', 6000, 'removed', interval '200 days'),
             ('old_back', 5900, 'active',  interval '100 days')) v(sid, price, status, age)
where m.slug = 'yamaha-mt-07';

update public.listings b
set relisted_from = g.id, relisted_price = g.price
from public.listings g
where (b.source_listing_id, g.source_listing_id) in (('back', 'gone'), ('old_back', 'old_gone'));

insert into public.saved_searches (id, user_id, name, is_active)
values ('00000000-0000-0000-0000-00000000005a', '00000000-0000-0000-0000-0000000000a2', 'MT', true),
       ('00000000-0000-0000-0000-00000000005b', '00000000-0000-0000-0000-0000000000a3', 'MT', true),
       ('00000000-0000-0000-0000-00000000005c', '00000000-0000-0000-0000-0000000000a4', 'MT', false);

insert into public.listing_favourites (user_id, listing_id)
select u, l.id
from public.listings l,
     unnest(array['00000000-0000-0000-0000-0000000000a1',
                  '00000000-0000-0000-0000-0000000000a3']::uuid[]) u
where l.source_listing_id in ('gone', 'old_gone');

insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
select s.user_id, s.id, l.id, 'new_listing', l.price
from public.saved_searches s, public.listings l
where l.source_listing_id = 'gone';

do $$
declare
  n int;
  a3 public.alerts;
begin
  n := public.generate_back_on_market_alerts();
  assert n = 3, format('a1, a2 and a3, got %s', n);
  assert (select count(*) from public.alerts a join public.listings l on l.id = a.listing_id
          where a.type = 'back_on_market' and l.source_listing_id = 'back') = 3,
    'all on the new ad, none for the old relist';
  assert not exists (select 1 from public.alerts
                     where type = 'back_on_market'
                       and user_id in ('00000000-0000-0000-0000-0000000000a4',
                                       '00000000-0000-0000-0000-0000000000a5')),
    'not for an inactive search or someone who never followed it';

  select * into a3 from public.alerts
  where type = 'back_on_market' and user_id = '00000000-0000-0000-0000-0000000000a3';
  assert a3.saved_search_id is null, 'the favourite wins over the search';
  assert a3.old_price = 7000 and a3.new_price = 6800, 'old and new price';

  assert (select saved_search_id from public.alerts
          where type = 'back_on_market' and user_id = '00000000-0000-0000-0000-0000000000a2')
         = '00000000-0000-0000-0000-00000000005a', 'the search that alerted';

  n := public.generate_back_on_market_alerts();
  assert n = 0, format('only once, got %s', n);
  -- Part of the collector's single entry point.
  assert public.generate_alerts() >= 0;
  assert (select count(*) from public.alerts where type = 'back_on_market') = 3;
end $$;
