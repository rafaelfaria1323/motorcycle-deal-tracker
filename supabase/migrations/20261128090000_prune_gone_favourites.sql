-- A favourite whose ad is gone leaves the list by itself (N.124, Rafael:
-- "if the ad was removed it should be automatically removed from the
-- favourites"). Not at once: a run that misses an ad marks it removed and
-- the next full read brings it back, so the favourite (its note, checklist
-- and visit) waits a day after the ad was last seen. The removal alert
-- and its push come in the run that removes the ad, before this.
create function public.prune_gone_favourites(p_at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.listing_favourites f
  using public.listings l
  where l.id = f.listing_id
    and l.status in ('removed', 'sold')
    and l.last_seen_at < p_at - interval '1 day';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.prune_gone_favourites(timestamptz)
  from public, anon, authenticated;

-- Hourly, so a favourite goes about a day after its ad.
select cron.schedule(
  'prune-gone-favourites',
  '29 * * * *',
  $job$ select public.prune_gone_favourites() $job$
);
