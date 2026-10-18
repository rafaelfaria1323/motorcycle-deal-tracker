-- Which price change an alert is about, so each change alerts once.
alter table public.alerts
  add column price_history_id uuid
    references public.listing_price_history (id) on delete cascade;

create unique index alerts_one_reduction_per_user_and_change
  on public.alerts (user_id, price_history_id)
  where type = 'price_reduction';

-- Alerts for price drops of at least p_min_drop_pct percent on listings that
-- match a search wanting price-reduction notifications. A drop only counts
-- if it happened after the search was saved. Safe to run repeatedly.
create function public.generate_price_reduction_alerts(
  p_min_drop_pct numeric default 1
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (
    user_id, saved_search_id, listing_id, type,
    old_price, new_price, price_history_id
  )
  select distinct on (s.user_id, c.history_id)
         s.user_id, s.id, c.listing_id, 'price_reduction'::public.alert_type,
         c.old_price, c.new_price, c.history_id
  from (
    select h.id as history_id,
           h.listing_id,
           h.observed_at,
           h.price as new_price,
           lag(h.price) over (
             partition by h.listing_id order by h.observed_at, h.id
           ) as old_price
    from public.listing_price_history h
  ) c
  join public.saved_search_matches m on m.listing_id = c.listing_id
  join public.saved_searches s on s.id = m.saved_search_id
  where c.old_price is not null
    and c.new_price < c.old_price
    and (c.old_price - c.new_price) / c.old_price * 100 >= p_min_drop_pct
    and s.is_active
    and s.notify_price_reduction
    and c.observed_at > s.created_at
  order by s.user_id, c.history_id, s.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_price_reduction_alerts(numeric)
  from public, anon, authenticated;

-- The collector's single entry point now creates both kinds.
create or replace function public.generate_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.generate_new_listing_alerts()
       + public.generate_price_reduction_alerts();
end;
$$;