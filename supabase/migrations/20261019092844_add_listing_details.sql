-- Facts only the listing page has. Null = unknown (not read, or not stated).
alter table public.listings
  add column registrations          smallint,
  add column service_book           boolean,
  add column origin                 text,
  add column warranty_until         date,
  add column dealer_warranty_months smallint,
  add column published_at           timestamptz,
  add column details_checked_at     timestamptz;

-- Called by the collector: p_details is a JSON array of objects keyed like
-- the columns plus source_listing_id. A value missing from the page never
-- erases one already known. Returns how many listings were updated.
create function public.apply_listing_details(p_source text, p_details jsonb)
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
      published_at           = coalesce(d.published_at, l.published_at),
      details_checked_at     = now()
  from jsonb_to_recordset(p_details) as d(
    source_listing_id      text,
    description            text,
    registrations          smallint,
    service_book           boolean,
    origin                 text,
    warranty_until         date,
    dealer_warranty_months smallint,
    published_at           timestamptz
  )
  where l.source = p_source
    and l.source_listing_id = d.source_listing_id;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_listing_details(text, jsonb)
  from public, anon, authenticated;