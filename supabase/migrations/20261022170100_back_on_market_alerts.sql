-- "Voltou ao mercado": when a gone ad comes back as a new one (a relist,
-- found by mark_relists through mark_duplicates before the alerts run),
-- tell the people who followed the earlier ad: it was a favourite, or one
-- of their active saved searches alerted them about it. One alert per
-- person per new ad (the favourite's when both); old_price is the earlier
-- ad's last price. Only relists first seen in the last 14 days, so the
-- first run doesn't bring up old ones. Safe to run repeatedly.
create unique index alerts_one_back_on_market_per_user
  on public.alerts (user_id, listing_id)
  where type = 'back_on_market';

create function public.generate_back_on_market_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (
    user_id, saved_search_id, listing_id, type, old_price, new_price
  )
  select distinct on (w.user_id, l.id)
         w.user_id, w.saved_search_id, l.id,
         'back_on_market'::public.alert_type, l.relisted_price, l.price
  from public.listings l
  join (
    select f.user_id, f.listing_id, null::uuid as saved_search_id, 0 as rank
    from public.listing_favourites f
    union all
    select a.user_id, a.listing_id, s.id, 1
    from public.alerts a
    join public.saved_searches s on s.id = a.saved_search_id
    where s.is_active
      and a.type <> 'back_on_market'
  ) w on w.listing_id = l.relisted_from
  where l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.first_seen_at > now() - interval '14 days'
  order by w.user_id, l.id, w.rank
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_back_on_market_alerts()
  from public, anon, authenticated;

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
       + public.generate_listing_removed_alerts()
       + public.generate_favourite_alerts()
       + public.generate_back_on_market_alerts();
end;
$$;
