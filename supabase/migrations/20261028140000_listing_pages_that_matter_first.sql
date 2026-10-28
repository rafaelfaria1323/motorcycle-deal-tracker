-- Listing pages that matter first (R.5). When a run reaches its 30 minutes
-- per site, the Standvirtual listing pages still to read wait for the next
-- run. They used to be read newest first; now someone's favourites come
-- first, then listings someone was alerted about (alerts still shown), then
-- the rest by Deal Score (not yet scored, i.e. new in this run, first:
-- their score isn't known), newest first among equals. Same requests, but
-- what waits is what matters least.
--
-- The two older tiers stay ahead of that: pages that failed before wait
-- behind those never tried, and listings without details come before those
-- missing only the photos (details feed the scores).
create function public.listings_missing_details(p_source text, p_limit integer default null)
returns table (source_listing_id text, url text)
language sql
stable
security definer
set search_path = ''
as $$
  select l.source_listing_id, l.url
  from public.listings l
  where l.source = p_source
    and l.photos_read_at is null
    and l.motorcycle_id is not null
    and l.duplicate_of is null
    and l.status in ('active', 'price_changed')
  order by
    l.details_failed_at nulls first,
    l.details_checked_at nulls first,
    case
      when exists (select 1 from public.listing_favourites f where f.listing_id = l.id) then 0
      when exists (select 1 from public.alerts a
                   where a.listing_id = l.id and a.dismissed_at is null) then 1
      else 2
    end,
    l.deal_score desc nulls first,
    l.first_seen_at desc,
    l.id
  limit p_limit;
$$;

revoke all on function public.listings_missing_details(text, integer)
  from public, anon, authenticated;
