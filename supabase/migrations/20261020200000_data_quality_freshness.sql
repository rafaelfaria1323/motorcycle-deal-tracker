-- Data-quality monitoring (11.5): two more columns per site.
-- last_seen_at: the latest time any of its live listings was seen on the
-- site. Listings are only removed by searches read in full, so when a site
-- stops answering its listings stay live and this goes stale.
-- sharp_price_changes: live listings whose price moved by half or more in
-- one step in the last 30 days (7 500 -> 750 is a misread, not a deal).
-- New columns go at the end, so `create or replace` keeps the old ones.
create or replace view public.source_data_quality
with (security_invoker = true) as
with steps as (
  select
    h.listing_id,
    h.observed_at,
    h.price,
    lag(h.price) over (partition by h.listing_id
                       order by h.observed_at, h.id) as previous_price
  from public.listing_price_history h
),
sharp as (
  select distinct s.listing_id
  from steps s
  where s.observed_at >= now() - interval '30 days'
    and s.previous_price > 0
    and (s.price >= s.previous_price * 1.5
         or s.price <= s.previous_price * 0.5)
)
select
  l.source,
  count(*)                                                   as live_count,
  count(*) filter (where l.motorcycle_id is null)            as unmatched_count,
  count(*) filter (where l.duplicate_of is not null)         as duplicate_count,
  count(*) filter (where l.motorcycle_id is not null
                     and l.duplicate_of is null)             as scored_count,
  count(*) filter (where l.motorcycle_id is not null
                     and l.duplicate_of is null
                     and l.year is null)                     as missing_year,
  count(*) filter (where l.motorcycle_id is not null
                     and l.duplicate_of is null
                     and l.mileage is null)                  as missing_mileage,
  count(*) filter (where l.motorcycle_id is not null
                     and l.duplicate_of is null
                     and nullif(trim(l.location), '') is null) as missing_location,
  -- Standvirtual listing pages still to read (OLX has no listing pages).
  count(*) filter (where l.source = 'standvirtual'
                     and l.motorcycle_id is not null
                     and l.duplicate_of is null
                     and l.details_checked_at is null)       as details_pending,
  max(l.last_seen_at)                                        as last_seen_at,
  count(*) filter (where l.id in (select listing_id from sharp))
                                                             as sharp_price_changes
from public.listings l
where l.status in ('active', 'price_changed')
group by l.source;
