-- Normalized motorcycle listings, one row per source listing.
create type public.listing_status as enum (
  'active', 'price_changed', 'removed', 'sold', 'unknown'
);

create type public.seller_type as enum ('private', 'dealer', 'unknown');

create table public.listings (
  id                uuid primary key default gen_random_uuid(),

  -- source identity (a listing is unique per source)
  source            text not null,
  source_listing_id text not null,
  url               text not null,

  -- what the bike is
  motorcycle_id     uuid references public.motorcycles (id),
  brand             text not null,
  model             text not null,
  variant           text,
  year              smallint,
  mileage           integer check (mileage >= 0),
  price             numeric(10, 2) check (price >= 0),

  -- seller
  seller_type       public.seller_type not null default 'unknown',
  seller_name       text,
  location          text,

  -- content
  description       text,
  images            text[] not null default '{}',

  -- lifecycle (visible vs. last check vs. last confirmed active)
  status            public.listing_status not null default 'active',
  first_seen_at     timestamptz not null default now(),
  last_seen_at      timestamptz not null default now(),
  last_checked_at   timestamptz not null default now(),

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique (source, source_listing_id)
);

-- Public read-only for now; writes come from the backend/service role.
alter table public.listings enable row level security;

create policy "Listings are readable by everyone"
  on public.listings
  for select
  to anon, authenticated
  using (true);