-- One new-listing alert per person per listing, even if several of their
-- searches match it. (Other alert types may repeat, so only this type.)
create unique index alerts_one_new_listing_per_user
  on public.alerts (user_id, listing_id)
  where type = 'new_listing';

-- Alerts for live listings that appeared after a search was saved and match
-- a search that wants new-listing notifications. Safe to run repeatedly.
-- Returns how many alerts were created.
create function public.generate_new_listing_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
  select distinct on (s.user_id, l.id)
         s.user_id, s.id, l.id, 'new_listing'::public.alert_type, l.price
  from public.saved_search_matches m
  join public.saved_searches s on s.id = m.saved_search_id
  join public.listings l on l.id = m.listing_id
  where s.is_active
    and s.notify_new_listing
    and l.first_seen_at > s.created_at
  order by s.user_id, l.id, s.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- One entry point for the collector. Each alert type adds a line here.
create function public.generate_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.generate_new_listing_alerts();
end;
$$;

revoke all on function public.generate_new_listing_alerts()
  from public, anon, authenticated;
revoke all on function public.generate_alerts()
  from public, anon, authenticated;