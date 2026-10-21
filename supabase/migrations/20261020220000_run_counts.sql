-- What each run did, totals over both sites ({"new": 3, "price_changes": 2,
-- "removed": 1, "alerts": 4}), from refresh.dart's log lines (11.3). Shown
-- in Mais next to the last run. Older runs keep {}.
alter table public.collector_runs
  add column counts jsonb not null default '{}'::jsonb;
