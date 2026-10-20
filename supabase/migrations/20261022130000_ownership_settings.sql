-- Cost of ownership (15.4): the figures only the owner knows, kept per
-- account so every listing page uses them. The tables (IUC, tyres,
-- services) live in the app (ownership_cost.dart).
create table public.ownership_settings (
  user_id            uuid primary key default auth.uid()
                       references auth.users (id) on delete cascade,
  -- The owner's own insurance quote, in euros per year; null: not given.
  insurance_per_year integer check (insurance_per_year between 0 and 20000),
  km_per_year        integer not null default 5000
                       check (km_per_year between 0 and 100000),
  years_to_keep      smallint not null default 3
                       check (years_to_keep between 1 and 15),
  updated_at         timestamptz not null default now()
);

-- Owner-only, like favourites.
alter table public.ownership_settings enable row level security;

create policy "Users manage their own ownership settings"
  on public.ownership_settings
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
