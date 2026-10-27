-- How a run went, in more detail (N.23), written by report_run.dart:
-- 'partial' = only a site's passing fetch failure (a timeout, a dropped
-- connection or an HTTP error still there after the retry) in a run that
-- got to its end; the admins are told only when the same site fails again
-- in the next run. scoring_ms = how long recalculate_deal_scores() took
-- (the collector role's statement timeout is 60 s); null for older runs or
-- a run that stopped before the scores.
alter table public.collector_runs
  add column scoring_ms integer check (scoring_ms >= 0);

alter table public.collector_runs
  drop constraint collector_runs_status_check;

alter table public.collector_runs
  add constraint collector_runs_status_check
  check (status in ('ok', 'partial', 'blocked', 'failed'));
