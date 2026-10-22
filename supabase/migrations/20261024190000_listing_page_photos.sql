-- Standvirtual's search results carry one thumbnail per ad; its listing
-- page has every photo. apply_listing_details now stores them, and
-- photos_read_at says a listing's page photos were read, so listings whose
-- details were read before this (one photo each) are read again for them.
alter table public.listings add column photos_read_at timestamptz;

create or replace function public.apply_listing_details(p_source text, p_details jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set description            = coalesce(d.description, l.description),
      registrations          = coalesce(d.registrations, l.registrations),
      service_book           = coalesce(d.service_book, l.service_book),
      origin                 = coalesce(d.origin, l.origin),
      warranty_until         = coalesce(d.warranty_until, l.warranty_until),
      dealer_warranty_months = coalesce(d.dealer_warranty_months,
                                        l.dealer_warranty_months),
      published_at           = least(d.published_at, l.published_at),
      -- A page without photos keeps the search's thumbnail.
      images                 = case when cardinality(d.images) > 0
                                    then d.images else l.images end,
      details_checked_at     = now(),
      photos_read_at         = now()
  from jsonb_to_recordset(p_details) as d(
    source_listing_id      text,
    description            text,
    registrations          smallint,
    service_book           boolean,
    origin                 text,
    warranty_until         date,
    dealer_warranty_months smallint,
    published_at           timestamptz,
    images                 text[]
  )
  where l.source = p_source
    and l.source_listing_id = d.source_listing_id;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_listing_details(text, jsonb)
  from public, anon, authenticated;

-- A page read again only for its photos can fail too (the ad is gone): it
-- then waits behind the others like a failed first read.
create or replace function public.mark_details_failed(p_source text, p_ids text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set details_failed_at = now()
  where source = p_source
    and source_listing_id = any (p_ids)
    and photos_read_at is null;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.mark_details_failed(text, text[])
  from public, anon, authenticated;
