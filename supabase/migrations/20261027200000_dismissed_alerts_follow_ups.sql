-- A deleted alert (dismiss_alert) no longer brings the listing's later
-- news. "Anúncio removido" and "De volta ao mercado" follow the alerts a
-- person was sent about a listing, and they counted the deleted ones too,
-- so a bike someone had put away still alerted them when its ad ended or
-- came back. Now only alerts still shown count; a favourite still does,
-- and so does another alert about the same listing that wasn't deleted.

create or replace function public.generate_listing_removed_alerts()
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
    and a.dismissed_at is null
    and s.is_active
    and s.notify_listing_removed
    and l.status = 'removed'
    and l.last_checked_at > now() - interval '1 day'
    and not exists (select 1 from public.alerts r
                    where r.user_id = a.user_id
                      and r.listing_id = a.listing_id
                      and r.type = 'listing_removed'
                      and r.created_at >= l.last_checked_at)
  order by a.user_id, a.listing_id, a.created_at;

  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.generate_back_on_market_alerts()
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
      and a.dismissed_at is null
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
