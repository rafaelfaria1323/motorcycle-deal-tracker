-- Favourites: the listings a person is considering, each with a private
-- note ("liguei, ainda disponível"). Kept for removed listings too, so the
-- shortlist shows what was sold.
create table public.listing_favourites (
  user_id    uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  note       text check (char_length(note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create index listing_favourites_listing_idx on public.listing_favourites (listing_id);

-- Owner-only, like saved searches.
alter table public.listing_favourites enable row level security;

create policy "Users manage their own favourites"
  on public.listing_favourites
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- A favourite always tells its owner about price drops and removal, whether
-- or not a saved search covers it (saved_search_id is null). Only events
-- after it became a favourite. The unique indexes on alerts keep one alert
-- per price change and one removal per listing, so a listing that is both
-- a favourite and in a saved search alerts once. Safe to run repeatedly.
create function public.generate_favourite_alerts(p_min_drop_pct numeric default 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  drops   integer;
  removed integer;
begin
  insert into public.alerts (
    user_id, listing_id, type, old_price, new_price, price_history_id
  )
  select f.user_id, c.listing_id, 'price_reduction'::public.alert_type,
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
  join public.listing_favourites f on f.listing_id = c.listing_id
  where c.old_price is not null
    and c.new_price < c.old_price
    and (c.old_price - c.new_price) / c.old_price * 100 >= p_min_drop_pct
    and c.observed_at > f.created_at
  on conflict do nothing;
  get diagnostics drops = row_count;

  insert into public.alerts (user_id, listing_id, type, new_price)
  select f.user_id, l.id, 'listing_removed'::public.alert_type, l.price
  from public.listing_favourites f
  join public.listings l on l.id = f.listing_id
  where l.status = 'removed'
    and l.last_checked_at > f.created_at
  on conflict do nothing;
  get diagnostics removed = row_count;

  return drops + removed;
end;
$$;

revoke all on function public.generate_favourite_alerts(numeric)
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
       + public.generate_favourite_alerts();
end;
$$;
