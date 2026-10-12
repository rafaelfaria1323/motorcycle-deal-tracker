-- One row per observed price for a listing. The first row is the initial price.
create table public.listing_price_history (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings (id) on delete cascade,
  price       numeric(10, 2) not null check (price >= 0),
  observed_at timestamptz not null default now()
);

-- "Price timeline for this listing, newest first" is the main query.
create index listing_price_history_listing_observed_idx
  on public.listing_price_history (listing_id, observed_at desc);

alter table public.listing_price_history enable row level security;

create policy "Price history is readable by everyone"
  on public.listing_price_history
  for select
  to anon, authenticated
  using (true);