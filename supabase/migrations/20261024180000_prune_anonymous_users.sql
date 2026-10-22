-- Every new browser (and every Lighthouse run on a preview) signs in
-- anonymously, and those users were never removed. An anonymous user
-- owns nothing (saved searches, favourites, homes and devices need an
-- account), so one that has not used the app for 30 days is deleted:
-- created that long ago and no session of it used since (a running app
-- refreshes its session every hour). Supabase's own advice for anonymous
-- sign-ins; foreign keys cascade. Coming back later just signs in
-- anonymously again.
create function public.prune_anonymous_users(p_idle_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from auth.users u
  where u.is_anonymous
    and u.created_at < pg_catalog.now() - pg_catalog.make_interval(days => p_idle_days)
    and not exists (
      select 1 from auth.sessions s
      where s.user_id = u.id
        -- greatest ignores nulls: the latest of the dates there are.
        and greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'utc')
            >= pg_catalog.now() - pg_catalog.make_interval(days => p_idle_days));
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.prune_anonymous_users(integer)
  from public, anon, authenticated;

select cron.schedule(
  'prune-anonymous-users',
  '43 3 * * *',
  $job$ select public.prune_anonymous_users() $job$
);
