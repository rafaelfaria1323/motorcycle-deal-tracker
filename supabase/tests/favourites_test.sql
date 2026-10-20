-- Favourites: each person sees and changes only their own; a favourite
-- alerts its owner about price drops and removal after it was added, once
-- even when a saved search covers the same listing.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f1'),
                                   ('00000000-0000-0000-0000-0000000000f2');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000
from public.motorcycles m, (values ('fav'), ('other'), ('gone')) v(sid)
where m.slug = 'yamaha-mt-07';
-- now() is fixed in a transaction: the first prices come before the favourites.
update public.listing_price_history set observed_at = now() - interval '2 hours';

-- A drop before the favourite was added never alerts.
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 6800, now() - interval '90 minutes' from public.listings where source_listing_id = 'fav';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f1';
set local test.jwt = '{"is_anonymous": false}';
insert into public.listing_favourites (listing_id, note, created_at)
select id, case source_listing_id when 'fav' then 'Liguei, ainda disponível' end,
       now() - interval '1 hour'
from public.listings where source_listing_id in ('fav', 'gone');
reset role;

-- The other person can neither see nor change these, nor add one for someone else.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f2';
do $$
declare
  refused boolean := false;
begin
  assert (select count(*) from public.listing_favourites) = 0, 'another person sees none';
  update public.listing_favourites set note = 'x';
  delete from public.listing_favourites;
  begin
    insert into public.listing_favourites (user_id, listing_id)
    select '00000000-0000-0000-0000-0000000000f1', id from public.listings limit 1;
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a favourite for someone else is refused';
end $$;
reset role;

do $$
declare
  u constant uuid := '00000000-0000-0000-0000-0000000000f1';
  n int;
begin
  assert (select count(*) from public.listing_favourites where user_id = u) = 2
         and (select note from public.listing_favourites f join public.listings l on l.id = f.listing_id
              where l.source_listing_id = 'fav') = 'Liguei, ainda disponível',
    'the other person changed nothing';

  n := public.generate_alerts();
  assert n = 0, format('nothing happened since the favourites, got %s alerts', n);

  -- 6800 -> 6500 (4.4 %) on the favourite, 7000 -> 6000 on a listing nobody follows.
  perform public.apply_price_updates('olx', '{"fav": 6500, "other": 6000}');
  perform public.mark_removed_listings('olx', array['fav', 'other'], 1);
  perform public.generate_alerts();

  assert (select count(*) from public.alerts) = 2, 'one drop and one removal, for the owner only';
  assert (select (old_price, new_price) = (6800::numeric, 6500::numeric) and saved_search_id is null
          from public.alerts where type = 'price_reduction' and user_id = u),
    'the drop carries both prices and no saved search';
  assert (select l.source_listing_id from public.alerts a join public.listings l on l.id = a.listing_id
          where a.type = 'listing_removed' and a.user_id = u) = 'gone',
    'the favourite that left the market';

  perform public.generate_alerts();
  assert (select count(*) from public.alerts) = 2, 'running again adds nothing';
end $$;

-- A saved search covering the same listing does not alert twice for the
-- same change (it does alert the earlier drop, made after it was saved).
insert into public.saved_searches (user_id, motorcycle_id, created_at)
select '00000000-0000-0000-0000-0000000000f1', id, now() - interval '3 hours'
from public.motorcycles where slug = 'yamaha-mt-07';
do $$
begin
  perform public.generate_alerts();
  assert (select count(*) from public.alerts
          where type = 'price_reduction' and new_price = 6500) = 1,
    'one alert per price change for a favourite also in a search';
end $$;
