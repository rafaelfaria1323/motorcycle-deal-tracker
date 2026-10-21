-- Bug hunt, part 2 (20261024110000_data_fixes.sql): alerts only for recent
-- events, a removal alert per removal, duplicate marks kept on removed
-- listings, OLX's thin descriptions, the earliest publication date.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1');
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year from auth.users u cross join public.motorcycles m
where m.is_active;

-- A search made a year ago; 'old' was first seen three days ago (it starts
-- matching only now, say the account just followed the model), 'fresh' now.
insert into public.saved_searches (id, user_id, motorcycle_id, created_at, notify_listing_removed)
select '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
       id, now() - interval '1 year', true
from public.motorcycles where slug = 'yamaha-mt-07';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, first_seen_at, seller_type, description)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000, v.seen,
       'private', 'Curta.'
from public.motorcycles m,
     (values ('old', now() - interval '3 days'), ('fresh', now())) v(sid, seen)
where m.slug = 'yamaha-mt-07';
update public.listing_price_history set observed_at = now() - interval '4 days';
-- A drop two days ago, another one now.
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 6800, now() - interval '2 days' from public.listings where source_listing_id = 'old';
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 6500, now() from public.listings where source_listing_id = 'old';

do $$
begin
  perform public.generate_alerts();
  assert (select array_agg(l.source_listing_id) from public.alerts a
          join public.listings l on l.id = a.listing_id
          where a.type = 'new_listing') = array['fresh'],
    'an ad first seen days ago is not new';
  assert (select array_agg(new_price) from public.alerts
          where type = 'price_reduction') = array[6500::numeric],
    'only the drop of the last day alerts';
end $$;

-- Removal: once per removal. 'fresh' (alerted) goes, comes back, goes again.
do $$
begin
  update public.listings set status = 'removed', last_checked_at = now() - interval '2 hours'
  where source_listing_id = 'fresh';
  perform public.generate_alerts();
  perform public.generate_alerts();
  assert (select count(*) from public.alerts where type = 'listing_removed') = 1,
    'one alert for one removal';

  -- The alert above is from an earlier run; the listing came back and went again.
  update public.alerts set created_at = now() - interval '1 hour' where type = 'listing_removed';
  update public.listings set status = 'removed', last_checked_at = now()
  where source_listing_id = 'fresh';
  perform public.generate_alerts();
  assert (select count(*) from public.alerts where type = 'listing_removed') = 2,
    'a second removal alerts again';
end $$;

-- A favourite removed twice alerts its owner twice, and a removal two days
-- old (before this change) doesn't arrive now.
insert into public.listing_favourites (user_id, listing_id, created_at)
select '00000000-0000-0000-0000-0000000000a1', id, now() - interval '3 days'
from public.listings where source_listing_id = 'old';
do $$
begin
  update public.listings set status = 'removed', last_checked_at = now() - interval '2 days'
  where source_listing_id = 'old';
  perform public.generate_alerts();
  assert not exists (select 1 from public.alerts a join public.listings l on l.id = a.listing_id
                     where a.type = 'listing_removed' and l.source_listing_id = 'old'),
    'an old removal is not alerted';

  update public.listings set last_checked_at = now() where source_listing_id = 'old';
  perform public.generate_alerts();
  perform public.generate_alerts();
  assert (select count(*) from public.alerts a join public.listings l on l.id = a.listing_id
          where a.type = 'listing_removed' and l.source_listing_id = 'old') = 1,
    'a favourite''s removal alerts once';
end $$;

-- OLX search results hold the whole description: a private seller's thin
-- one is a risk there without a listing page read.
do $$
begin
  update public.listings set status = 'active' where source_listing_id = 'fresh';
  assert (select 'thin_description' = any (r.reasons) from public.listing_risk_scores r
          join public.listings l on l.id = r.listing_id
          where l.source_listing_id = 'fresh'),
    'an OLX private ad with a thin description';
end $$;

-- Duplicates: a removed duplicate keeps its mark when the marks are worked
-- out again.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type, first_seen_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2022, 12400, 6500, 'Porto', 'MT-07 de 2022, sempre na garagem, revisões na marca, pneus novos.',
       'private', v.seen
from public.motorcycles m,
     (values ('olx', 'd1', now() - interval '3 days'), ('standvirtual', 'd2', now())) v(source, sid, seen)
where m.slug = 'yamaha-mt-07';
do $$
begin
  perform public.mark_duplicates();
  assert (select duplicate_of from public.listings where source_listing_id = 'd2')
       = (select id from public.listings where source_listing_id = 'd1');
  update public.listings set status = 'removed' where source_listing_id = 'd2';
  perform public.mark_duplicates();
  assert (select duplicate_of from public.listings where source_listing_id = 'd2')
       = (select id from public.listings where source_listing_id = 'd1'),
    'a removed duplicate keeps its mark';
end $$;

-- A listing page's publication date never moves the stored one later.
do $$
begin
  update public.listings set published_at = '2026-01-10' where source_listing_id = 'd1';
  perform public.apply_listing_details('olx',
    '[{"source_listing_id": "d1", "published_at": "2026-03-01T00:00:00Z"}]');
  assert (select published_at from public.listings where source_listing_id = 'd1')
       = '2026-01-10'::timestamptz, 'the earliest publication date is kept';
  perform public.apply_listing_details('olx',
    '[{"source_listing_id": "d1", "published_at": "2025-12-01T00:00:00Z"}]');
  assert (select published_at from public.listings where source_listing_id = 'd1')
       = '2025-12-01'::timestamptz;
end $$;

-- A listing page that failed is marked, a read one is not.
do $$
begin
  perform public.mark_details_failed('olx', array['d1', 'd2', 'nope']);
  assert (select details_failed_at from public.listings where source_listing_id = 'd1') is null,
    'a listing with details is not marked';
  assert (select count(*) from public.listings
          where details_failed_at is not null) = 0, 'd2 is on another site';
  perform public.mark_details_failed('standvirtual', array['d2']);
  assert (select details_failed_at from public.listings where source_listing_id = 'd2') = now();
end $$;
