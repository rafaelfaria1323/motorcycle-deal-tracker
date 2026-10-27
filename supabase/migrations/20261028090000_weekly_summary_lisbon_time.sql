-- Rafael, 2026-10-28: the weekly summary at a fixed Lisbon time all year.
-- The job ran at 07:52 UTC (07:52 in Lisbon in winter, 08:52 in summer).
-- Now it checks at minute 52 of every Monday hour and starts the summary
-- only at 08:52 Lisbon time, after the 08:00 collection, as
-- collection_due() does for the collections.

-- Whether the weekly summary is due at p_now (Monday 08:xx, Lisbon).
create function public.weekly_summary_due(p_now timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select extract(isodow from p_now at time zone 'Europe/Lisbon') = 1
     and extract(hour from p_now at time zone 'Europe/Lisbon') = 8
$$;

-- Starts weekly-summary.yml when it is due; pg_net's request id, or null
-- when not due (or the token is missing).
create function public.dispatch_weekly_summary(p_now timestamptz default now())
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.weekly_summary_due(p_now) then
    return null;
  end if;
  return public.dispatch_workflow('weekly-summary.yml');
end;
$$;

revoke all on function public.weekly_summary_due(timestamptz)
  from public, anon, authenticated;
revoke all on function public.dispatch_weekly_summary(timestamptz)
  from public, anon, authenticated;

-- Replaces the job of the same name. Monday in Lisbon at 08:xx is always
-- Monday in UTC (Lisbon is UTC or UTC+1).
select cron.schedule(
  'weekly-summary',
  '52 * * * 1',
  $job$ select public.dispatch_weekly_summary() $job$
);
