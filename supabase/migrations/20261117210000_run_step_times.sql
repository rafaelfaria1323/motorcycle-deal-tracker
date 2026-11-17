-- How long each step of a run took (N.118), written by report_run.dart
-- from refresh.dart's report: per part of the run (each site in the order
-- read, then `all` for what runs once), each step's milliseconds, e.g.
-- {"olx": {"fetch": 74000, "save": 3600}, "all": {"scores": 2100}}.
-- Shown to admins in "Estado da recolha" ("Onde vai o tempo"); null for
-- older runs and runs that left no report.
alter table public.collector_runs
  add column steps_ms jsonb
  check (steps_ms is null or jsonb_typeof(steps_ms) = 'object');
