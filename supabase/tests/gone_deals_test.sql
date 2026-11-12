-- Good deals that went fast (20261112170000_gone_deals.sql): a model's
-- gone ads that likely sold, with their last Deal Score and days on sale.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, first_seen_at, published_at,
                             last_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 2020, 20000,
       v.price, v.status::public.listing_status,
       now() - make_interval(days => v.found),
       case when v.published is null then null
            else now() - make_interval(days => v.published) end,
       now() - make_interval(days => v.gone)
from public.motorcycles m,
     (values ('gd-fast', 6000, 'removed', 14, 15, 10),
             ('gd-slow', 7000, 'removed', 60, null, 5),
             ('gd-live', 7000, 'active', 10, null, 0),
             ('gd-old', 7000, 'removed', 200, null, 120),
             ('gd-parts', 1, 'removed', 20, null, 5),
             ('gd-back', 7000, 'removed', 40, null, 30))
       v(sid, price, status, found, published, gone)
where m.slug = 'yamaha-mt-07';
-- The Deal Score last held, kept by the trigger.
update public.listings set deal_score = 86 where source_listing_id = 'gd-fast';
update public.listings set deal_score = 55 where source_listing_id = 'gd-slow';
-- gd-back came back as a new ad: relisted, not sold.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, relisted_from)
select 'olx', 'gd-relist', 'https://x/gd-relist', m.id, m.brand, m.model, 2020, 20000,
       7000, (select id from public.listings where source_listing_id = 'gd-back')
from public.motorcycles m where m.slug = 'yamaha-mt-07';
-- A gone duplicate of a gone ad.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, duplicate_of)
select 'standvirtual', 'gd-dup', 'https://x/gd-dup', m.id, m.brand, m.model, 2020,
       20000, 6000, 'removed',
       (select id from public.listings where source_listing_id = 'gd-fast')
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  ids text[];
  v record;
begin
  select array_agg(l.source_listing_id order by g.gone_at desc) into ids
  from public.gone_deals(mt07) g
  join public.listings l on l.id = g.listing_id;
  assert ids = array['gd-slow', 'gd-fast'], format('likely sales only, got %s', ids);

  select * into v from public.gone_deals(mt07) g
  where g.listing_id = (select id from public.listings where source_listing_id = 'gd-fast');
  assert v.deal_score = 86, format('last score, got %s', v.deal_score);
  -- On sale from its publication (15 days ago) to 10 days ago.
  assert v.days_listed = 5, format('from publication, got %s', v.days_listed);
  assert v.year = 2020 and v.mileage = 20000 and v.price = 6000, 'the ad''s facts';

  select * into v from public.gone_deals(mt07) g
  where g.listing_id = (select id from public.listings where source_listing_id = 'gd-slow');
  -- No publication date: from when it was first seen.
  assert v.days_listed = 55 and v.deal_score = 55,
    format('from first seen, got %s days, score %s', v.days_listed, v.deal_score);

  -- A shorter window leaves out the older exit.
  assert (select count(*) from public.gone_deals(mt07, 7)) = 1, 'within 7 days';
  -- Another model: nothing.
  assert not exists (select 1 from public.gone_deals(
    (select id from public.motorcycles where slug = 'yamaha-r7'))), 'other model';
end $$;

do $$
begin
  assert has_function_privilege('anon', 'public.gone_deals(uuid, integer)', 'execute'),
    'visitors can read it';
  assert has_function_privilege('authenticated', 'public.gone_deals(uuid, integer)', 'execute'),
    'accounts can read it';
end $$;
