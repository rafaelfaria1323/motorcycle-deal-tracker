-- Rafael, 2026-10-22: collections at fixed hours of the Portuguese day
-- instead of every 4 hours: 00:00, 08:00, then every 2 hours from 12:00 to
-- 20:00 (Lisbon time). pg_cron counts in UTC, so the job runs every hour
-- and starts the collection only at those Lisbon hours, which keeps them
-- right across summer time. The fetching caps are unchanged (20 requests
-- per run, 120 per day per site). collection_text.dart in the app mirrors
-- these hours: change both together.

-- Whether a collection is due at p_now (its Lisbon hour is one of them).
create function public.collection_due(p_now timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select extract(hour from p_now at time zone 'Europe/Lisbon')::integer
         = any (array[0, 8, 12, 14, 16, 18, 20])
$$;

-- Starts collect.yml when a collection is due; pg_net's request id, or
-- null when not due (or the token is missing).
create function public.dispatch_collection(p_now timestamptz default now())
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.collection_due(p_now) then
    return null;
  end if;
  return public.dispatch_workflow('collect.yml');
end;
$$;

revoke all on function public.collection_due(timestamptz)
  from public, anon, authenticated;
revoke all on function public.dispatch_collection(timestamptz)
  from public, anon, authenticated;

-- Replaces the job of the same name.
select cron.schedule(
  'collect-listings',
  '0 * * * *',
  $job$ select public.dispatch_collection() $job$
);
