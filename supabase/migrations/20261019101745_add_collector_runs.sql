-- One row per scheduled collection, so a failure is visible without logging
-- into the machine that runs it.
create table public.collector_runs (
  id          bigint generated always as identity primary key,
  started_at  timestamptz not null,
  finished_at timestamptz not null default now(),
  status      text not null check (status in ('ok', 'blocked', 'failed')),
  summary     text
);

alter table public.collector_runs enable row level security;

-- Only signed-in (non-anonymous) users can read it; only the collector's
-- service key writes it.
create policy "account users read runs"
  on public.collector_runs
  for select
  to authenticated
  using (coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);