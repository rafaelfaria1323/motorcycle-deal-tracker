-- Listing pages that matter first (20261028140000): failed pages last,
-- missing details before missing photos, then favourites, alerted
-- listings, unscored ones, by Deal Score, newest first.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a5');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, first_seen_at)
select 'standvirtual', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000,
       now() - v.age * interval '1 day'
from public.motorcycles m,
     (values ('failed', 0), ('photos', 0), ('fav', 9), ('alerted', 8), ('dismissed', 0),
             ('new', 7), ('high', 6), ('low', 1), ('old-low', 5), ('gone', 0), ('olx', 0)) v(sid, age)
where m.slug = 'yamaha-mt-07';

update public.listings set source = 'olx' where source_listing_id = 'olx';
update public.listings set status = 'removed' where source_listing_id = 'gone';
update public.listings set details_failed_at = now() where source_listing_id = 'failed';
update public.listings set details_checked_at = now() where source_listing_id = 'photos';
update public.listings
set deal_score = case source_listing_id
                   when 'high' then 90 when 'low' then 40 when 'old-low' then 40
                   when 'dismissed' then 95 else 20 end
where source_listing_id not in ('new');

insert into public.listing_favourites (user_id, listing_id)
select '00000000-0000-0000-0000-0000000000a5', id from public.listings
where source_listing_id = 'fav';
insert into public.alerts (user_id, listing_id, type, dismissed_at)
select '00000000-0000-0000-0000-0000000000a5', id, 'new_listing',
       case source_listing_id when 'dismissed' then now() end
from public.listings where source_listing_id in ('alerted', 'dismissed');

do $$
declare
  got text[];
begin
  select array_agg(source_listing_id) into got
  from public.listings_missing_details('standvirtual');
  assert got = array['fav', 'alerted', 'new', 'dismissed', 'high', 'low', 'old-low',
                     'photos', 'failed'],
    format('order: %s', got);

  select array_agg(source_listing_id) into got
  from public.listings_missing_details('standvirtual', 2);
  assert got = array['fav', 'alerted'], format('limited: %s', got);
end $$;

do $$
begin
  assert not has_function_privilege('anon',
    'public.listings_missing_details(text, integer)', 'execute'), 'anon cannot call it';
  assert not has_function_privilege('authenticated',
    'public.listings_missing_details(text, integer)', 'execute'), 'accounts cannot call it';
end $$;
