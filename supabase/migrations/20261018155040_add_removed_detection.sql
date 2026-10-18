-- Seeing a listing again also confirms it was checked, and brings back one
-- that had been marked removed.
create or replace function public.mark_listings_seen(p_source text, p_ids text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set last_seen_at    = now(),
      last_checked_at = now(),
      status = case
        when status = 'removed' then 'active'::public.listing_status
        else status
      end
  where source = p_source
    and source_listing_id = any (p_ids);

  get diagnostics n = row_count;
  return n;
end;
$$;

-- For a COMPLETE import of one source: live listings missing from it are
-- marked removed. Refuses an empty import, and one that would remove more
-- than p_max_fraction of the source's live listings.
create function public.mark_removed_listings(
  p_source       text,
  p_seen_ids     text[],
  p_max_fraction numeric default 0.5
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

  select count(*) into live_count
  from public.listings
  where source = p_source
    and status in ('active', 'price_changed');

  select count(*) into missing_count
  from public.listings
  where source = p_source
    and status in ('active', 'price_changed')
    and source_listing_id <> all (p_seen_ids);

  if live_count > 0
     and missing_count::numeric / live_count > p_max_fraction then
    raise exception
      'Refusing to remove % of % live listings (limit % percent). Check the file, or use --force.',
      missing_count, live_count, round(p_max_fraction * 100);
  end if;

  update public.listings
  set status = 'removed',
      last_checked_at = now()
  where source = p_source
    and status in ('active', 'price_changed')
    and source_listing_id <> all (p_seen_ids);

  return missing_count;
end;
$$;

revoke all on function public.mark_removed_listings(text, text[], numeric)
  from public, anon, authenticated;