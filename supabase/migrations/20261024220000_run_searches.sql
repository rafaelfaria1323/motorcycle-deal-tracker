-- What each search cost and gave in a run (R.1), from importBatch's
-- "Search (<site>): ..." log lines (report_run.dart, searchesRead): a list
-- of {"site", "search" (its models), "pages" (read), "spans" (the site's
-- page count, null when the first page wasn't read), "ads", "followed",
-- "in_full"}. Shown to admins in "Estado da recolha". Older runs keep [].
alter table public.collector_runs
  add column searches jsonb not null default '[]'::jsonb;
