-- User-defined search criteria plus which alerts they want.
-- Criteria columns are optional: null means "any".
create table public.saved_searches (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null default auth.uid()
                            references auth.users (id) on delete cascade,
  name                    text,

  -- criteria
  motorcycle_id           uuid references public.motorcycles (id),
  min_year                smallint,
  max_price               numeric(10, 2) check (max_price >= 0),
  max_mileage             integer check (max_mileage >= 0),
  location                text,
  seller_type             public.seller_type,   -- null = private + dealer

  -- notification preferences
  notify_new_listing      boolean not null default true,
  notify_price_reduction  boolean not null default true,
  notify_excellent_deal   boolean not null default false,
  notify_listing_removed  boolean not null default false,

  is_active               boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index saved_searches_user_idx on public.saved_searches (user_id);

-- Owner-only: each user sees and manages only their own searches.
alter table public.saved_searches enable row level security;

create policy "Users manage their own saved searches"
  on public.saved_searches
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));