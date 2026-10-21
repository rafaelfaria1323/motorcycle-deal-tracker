-- "Chegou ao seu preço": a favourite's listing is on sale at its target
-- price or less, at a price seen after the target was set. old_price holds
-- the target, new_price the listing's price; one alert per target (a new
-- target can alert again). Safe to run repeatedly.
create unique index alerts_one_target_price_per_target
  on public.alerts (user_id, listing_id, old_price)
  where type = 'target_price_reached';

create function public.generate_target_price_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (user_id, listing_id, type, old_price, new_price)
  select f.user_id, l.id, 'target_price_reached'::public.alert_type,
         f.target_price, l.price
  from public.listing_favourites f
  join public.listings l on l.id = f.listing_id
  where f.target_price is not null
    and l.status in ('active', 'price_changed')
    and l.price <= f.target_price
    and exists (
      select 1
      from public.listing_price_history h
      where h.listing_id = l.id
        and h.price <= f.target_price
        and h.observed_at > f.target_set_at
    )
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_target_price_alerts()
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
       + public.generate_back_on_market_alerts()
       + public.generate_target_price_alerts();
end;
$$;
