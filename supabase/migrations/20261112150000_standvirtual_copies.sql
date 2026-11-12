-- OLX copies of Standvirtual ads (N.70). Standvirtual dealers' ads are
-- copied to OLX; the collector skipped every copy, trusting the
-- Standvirtual searches to find the original. They don't always: the
-- CBR650R search ("q-650") misses an ad titled only "Honda CBR". A copy
-- is now skipped only when its original is stored; otherwise it is
-- stored as an OLX ad, and duplicate detection links the two once
-- Standvirtual finds the original. A copy stored before stays one, so
-- it keeps being seen and updated.

-- p_copies: OLX listing id ('olx.pt/<id>') -> the Standvirtual ad code
-- of its original ('ID8Q1m16', from '...-ID8Q1m16.html'). Returns the
-- OLX ids to skip.
create or replace function public.olx_copies_to_skip(p_copies jsonb)
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select c.key
  from jsonb_each_text(coalesce(p_copies, '{}'::jsonb)) as c
  where c.value in (
      select substring(l.url from '-(ID[0-9A-Za-z]+)\.html')
      from public.listings l
      where l.source = 'standvirtual'
    )
    and not exists (
      select 1
      from public.listings o
      where o.source = 'olx'
        and o.source_listing_id = c.key
    );
$$;

revoke all on function public.olx_copies_to_skip(jsonb)
  from public, anon, authenticated;
grant execute on function public.olx_copies_to_skip(jsonb) to service_role;
