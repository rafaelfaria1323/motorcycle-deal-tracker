-- One removed-listing alert per person per listing, however often it
-- disappears and comes back.
create unique index alerts_one_removed_per_user
  on public.alerts (user_id, listing_id)
  where type = 'listing_removed';

-- Tells people who were already alerted about a listing that it is gone,
-- if the search that alerted them wants to hear about removals.
-- Safe to run repeatedly. Run it after removal detection.
create function public.generate_listing_removed_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
  select distinct on (a.user_id, a.listing_id)
         a.user_id, s.id, a.listing_id, 'listing_removed'::public.alert_type,
         l.price
  from public.alerts a
  join public.saved_searches s on s.id = a.saved_search_id
  join public.listings l on l.id = a.listing_id
  where a.type <> 'listing_removed'
    and s.is_active
    and s.notify_listing_removed
    and l.status = 'removed'
  order by a.user_id, a.listing_id, a.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_listing_removed_alerts()
  from public, anon, authenticated;

-- The collector's single entry point now creates all four kinds.
create or replace function public.generate_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.generate_new_listing_alerts()
       + public.generate_price_reduction_alerts()
       + public.generate_excellent_opportunity_alerts()
       + public.generate_listing_removed_alerts();
end;
$$;