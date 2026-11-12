-- "A minha mota" (N.67): the bikes an account bought, from an ad
-- ("Comprei esta") or typed in. The app values each one today
-- (`bike_value` at the purchase km plus the owner's km a year), against
-- the price paid, with its next maintenance. Owner-only, like
-- ownership_settings; never read by the collector or any score.
create table public.owned_bikes (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid()
                        references auth.users (id) on delete cascade,
  motorcycle_id       uuid not null
                        references public.motorcycles (id) on delete cascade,
  -- The ad it was bought from; a pruned ad leaves the bike.
  listing_id          uuid references public.listings (id) on delete set null,
  year                smallint not null check (year between 1950 and 2100),
  price_paid          integer check (price_paid between 0 and 200000),
  mileage_at_purchase integer check (mileage_at_purchase between 0 and 500000),
  bought_on           date not null default current_date,
  created_at          timestamptz not null default now(),
  -- One bike per ad and account: "Comprei esta" twice changes nothing
  -- (the app upserts on it). Bikes typed in have no ad, and nulls differ.
  constraint owned_bikes_user_listing unique (user_id, listing_id)
);

create index owned_bikes_motorcycle_id on public.owned_bikes (motorcycle_id);
create index owned_bikes_listing_id on public.owned_bikes (listing_id);

alter table public.owned_bikes enable row level security;

revoke all on public.owned_bikes from public, anon, authenticated;
grant select, insert, update, delete on public.owned_bikes to authenticated;

create policy "Accounts manage their own bikes"
  on public.owned_bikes
  for all to authenticated
  using (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  )
  with check (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  );
