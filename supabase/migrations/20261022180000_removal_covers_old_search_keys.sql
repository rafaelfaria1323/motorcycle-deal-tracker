-- A listing keeps the address of the search that last found it. When a
-- search's address changes (a model's first year edited, Standvirtual's
-- year filter added), listings that vanish before a run finds them again
-- keep the old address, which no search reads any more, so they were never
-- marked removed. A run that read every planned search in full
-- (p_include_unkeyed) now also covers them, but only for a tracked model
-- and within its years: listings of a model switched off, or older than
-- its first year, are no longer searched, which says nothing about them.
-- Whether a removal over p_search_keys covers listing l (see
-- mark_removed_listings).
create function public.in_removal_scope(
  l                 public.listings,
  p_search_keys     text[],
  p_include_unkeyed boolean
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_search_keys is null
      or l.search_key = any (p_search_keys)
      or (p_include_unkeyed and l.search_key is null)
      or (p_include_unkeyed
          and l.search_key <> all (p_search_keys)
          and exists (select 1
                      from public.motorcycles m
                      where m.id = l.motorcycle_id
                        and m.is_active
                        and (l.year is null or l.year >= m.min_year)));
$$;

revoke all on function public.in_removal_scope(public.listings, text[], boolean)
  from public, anon, authenticated;

create or replace function public.mark_removed_listings(
  p_source           text,
  p_seen_ids         text[],
  p_max_fraction     numeric default 0.5,
  p_search_keys      text[]  default null,
  p_include_unkeyed  boolean default true
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  live_count    integer;
  missing_count integer;
begin
  if p_seen_ids is null or cardinality(p_seen_ids) = 0 then
    raise exception
      'Refusing to mark listings as removed: the import contains no listings.';
  end if;

  select count(*),
         count(*) filter (where l.source_listing_id <> all (p_seen_ids))
  into live_count, missing_count
  from public.listings l
  where l.source = p_source
    and l.status in ('active', 'price_changed')
    and public.in_removal_scope(l, p_search_keys, p_include_unkeyed);

  if live_count > 0
     and missing_count::numeric / live_count > p_max_fraction then
    raise exception
      'Refusing to remove % of % live listings (limit % percent). Check the file, or use --force.',
      missing_count, live_count, round(p_max_fraction * 100);
  end if;

  update public.listings l
  set status = 'removed',
      last_checked_at = now()
  where l.source = p_source
    and l.status in ('active', 'price_changed')
    and public.in_removal_scope(l, p_search_keys, p_include_unkeyed)
    and l.source_listing_id <> all (p_seen_ids);

  return missing_count;
end;
$$;

revoke all on function public.mark_removed_listings(text, text[], numeric, text[], boolean)
  from public, anon, authenticated;
