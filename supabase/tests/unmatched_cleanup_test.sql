-- The one-time cleanup (20261023160000) already ran when the tests start;
-- run its statement again on fresh rows: unmatched live ads of the
-- collected sites go to removed, except those with an alert or a favourite;
-- matched ads stay; a later sighting makes one live again.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', v.sid, 'https://x/' || v.sid,
       case when v.matched then (select id from public.motorcycles where slug = 'yamaha-mt-07') end,
       'Yamaha', v.model, 5000
from (values ('r125', 'R125', false), ('r3', 'R3', false), ('alerted', 'R6', false),
             ('starred', 'R1', false), ('mt07', 'MT-07', true)) v(sid, model, matched);

insert into public.alerts (user_id, listing_id, type)
select '00000000-0000-0000-0000-0000000000a1', id, 'new_listing'
from public.listings where source_listing_id = 'alerted';
insert into public.listing_favourites (user_id, listing_id)
select '00000000-0000-0000-0000-0000000000a1', id
from public.listings where source_listing_id = 'starred';

update public.listings l
set status = 'removed'
where l.motorcycle_id is null
  and l.status in ('active', 'price_changed')
  and l.source in ('olx', 'standvirtual')
  and not exists (select 1 from public.alerts a where a.listing_id = l.id)
  and not exists (select 1 from public.listing_favourites f where f.listing_id = l.id);

do $$
begin
  assert (select array_agg(source_listing_id order by source_listing_id)
          from public.listings where status = 'removed') = array['r125', 'r3'],
    'only the unmatched ads nobody was told about or keeps';
  perform public.mark_listings_seen('olx', array['r3']);
  assert (select status from public.listings where source_listing_id = 'r3') = 'active',
    'seen again: live again';
end $$;
