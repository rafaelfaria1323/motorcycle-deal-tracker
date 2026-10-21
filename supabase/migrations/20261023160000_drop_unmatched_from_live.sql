-- OLX's family searches ("R", "CB"/"CBR") brought every model of the
-- family; the collector now asks OLX for the engine-size band of the models
-- searched (search_plan.dart, olxEngineBand), so the 125-500 cc bikes are no
-- longer read. The unmatched ads already stored stay "live" under the old
-- search addresses, which no search reads any more, so nothing would ever
-- mark them gone: they are set to removed now. The next run finds the ones
-- its searches still bring and makes them live again (mark_listings_seen).
-- Left alone: listings someone was alerted about or keeps as a favourite
-- (removing them would send a "removed" alert), and listings saved by hand
-- from other sites.
update public.listings l
set status = 'removed'
where l.motorcycle_id is null
  and l.status in ('active', 'price_changed')
  and l.source in ('olx', 'standvirtual')
  and not exists (select 1 from public.alerts a where a.listing_id = l.id)
  and not exists (select 1 from public.listing_favourites f where f.listing_id = l.id);
