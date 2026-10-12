-- Catalog of tracked motorcycle models. Listings will reference this table.
create table public.motorcycles (
  id         uuid primary key default gen_random_uuid(),
  brand      text not null,
  model      text not null,
  slug       text not null unique,
  min_year   smallint not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand, model)
);

-- The catalog is public read-only. With no write policies, only the
-- dashboard / service role can change it.
alter table public.motorcycles enable row level security;

create policy "Catalog is readable by everyone"
  on public.motorcycles
  for select
  to anon, authenticated
  using (true);

insert into public.motorcycles (brand, model, slug, min_year) values
  ('Yamaha', 'MT-07',   'yamaha-mt-07',   2026),
  ('Yamaha', 'R7',      'yamaha-r7',      2026),
  ('Honda',  'CB650R',  'honda-cb650r',   2025),
  ('Honda',  'CBR650R', 'honda-cbr650r',  2025);