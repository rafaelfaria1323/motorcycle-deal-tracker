-- N.125: a price that goes up alerts the people who follow that bike (a
-- favourite, or an alert still shown from an active saved search), once
-- per change, from 1 %, never from a placeholder price or before they
-- followed it.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1'),
                                   ('00000000-0000-0000-0000-0000000000c2'),
                                   ('00000000-0000-0000-0000-0000000000c3');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.price
from public.motorcycles m,
     (values ('up', 7000), ('tiny', 7000), ('ph', 1), ('early', 7000)) v(sid, price)
where m.slug = 'yamaha-mt-07';
update public.listing_price_history set observed_at = now() - interval '3 hours';

insert into public.listing_price_history (listing_id, price, observed_at)
select id, v.price, now() - interval '1 hour'
from public.listings l
join (values ('up', 8000), ('tiny', 7050), ('ph', 8000), ('early', 7900)) v(sid, price)
  on v.sid = l.source_listing_id;

-- c1 follows them as favourites; 'early' only after it went up.
insert into public.listing_favourites (user_id, listing_id, created_at)
select '00000000-0000-0000-0000-0000000000c1', id,
       case source_listing_id when 'early' then now() - interval '30 minutes'
                              else now() - interval '2 hours' end
from public.listings where source_listing_id in ('up', 'tiny', 'ph', 'early');

-- c2 was alerted about 'up' by a saved search; c3 too, but deleted it.
insert into public.saved_searches (id, user_id, motorcycle_id, created_at)
select v.id, v.user_id, m.id, now() - interval '3 hours'
from public.motorcycles m,
     (values ('00000000-0000-0000-0000-00000000c5c2'::uuid, '00000000-0000-0000-0000-0000000000c2'::uuid),
             ('00000000-0000-0000-0000-00000000c5c3'::uuid, '00000000-0000-0000-0000-0000000000c3'::uuid)) v(id, user_id)
where m.slug = 'yamaha-mt-07';
insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price, created_at, dismissed_at)
select v.user_id, v.search_id, l.id, 'new_listing', 7000, now() - interval '2 hours', v.dismissed
from public.listings l,
     (values ('00000000-0000-0000-0000-0000000000c2'::uuid, '00000000-0000-0000-0000-00000000c5c2'::uuid, null::timestamptz),
             ('00000000-0000-0000-0000-0000000000c3'::uuid, '00000000-0000-0000-0000-00000000c5c3'::uuid, now())) v(user_id, search_id, dismissed)
where l.source_listing_id = 'up';

do $$
declare
  r record;
begin
  assert public.generate_price_increase_alerts() = 2,
    'the favourite and the alerted search, nothing else';
  for r in select a.user_id, a.saved_search_id, a.old_price, a.new_price, l.source_listing_id
           from public.alerts a join public.listings l on l.id = a.listing_id
           where a.type = 'price_increase' order by a.user_id loop
    assert r.source_listing_id = 'up' and r.old_price = 7000 and r.new_price = 8000,
      format('7 000 -> 8 000 on "up", got %s', r);
  end loop;
  assert (select saved_search_id is null from public.alerts
          where type = 'price_increase'
            and user_id = '00000000-0000-0000-0000-0000000000c1'),
    'a favourite''s alert has no search';
  assert (select saved_search_id = '00000000-0000-0000-0000-00000000c5c2' from public.alerts
          where type = 'price_increase'
            and user_id = '00000000-0000-0000-0000-0000000000c2'),
    'the search that alerted it';
  assert public.generate_price_increase_alerts() = 0, 'once per change';
end $$;

-- A rise older than a day alerts nobody (the first run after the deploy).
update public.listing_price_history set observed_at = observed_at - interval '2 days';
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 9000, now() - interval '3 days' from public.listings where source_listing_id = 'tiny';
do $$
begin
  assert public.generate_price_increase_alerts() = 0, 'old rises stay quiet';
end $$;

-- generate_alerts runs it, and the test push can ask for one.
do $$
begin
  assert pg_get_functiondef('public.generate_alerts()'::regprocedure)
         like '%generate_price_increase_alerts%', 'part of every run';
  assert pg_get_functiondef('public.start_workflow(text, text)'::regprocedure)
         like '%''price_increase''%', 'a test push of a rise';
end $$;
