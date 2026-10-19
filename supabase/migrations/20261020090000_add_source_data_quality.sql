-- Data quality per site, shown in the app's "Mais": how many live listings
-- each site has, how many are tracked models, unmatched or duplicates, and
-- how many of the scored ones (matched, not duplicates) miss a fact the
-- scores use. Readable by everyone, like the listings it counts.
create view public.source_data_quality
with (security_invoker = true) as
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
                     and l.details_checked_at is null)       as details_pending
from public.listings l
where l.status in ('active', 'price_changed')
group by l.source;

grant select on public.source_data_quality to anon, authenticated;
