-- The API roles keep only the writes the app makes. Supabase grants anon
-- and authenticated every privilege on public's tables and leaves row level
-- security as the only guard; a table whose policies allow too much (or a
-- new table without RLS) would then be writable by anyone with the
-- publishable key. From now on a table the app writes needs its own grant
-- (the collector uses service_role and the functions run as their owner,
-- so neither is affected).

revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from anon, authenticated;

-- The app's own writes (each table's policies still limit them to the
-- caller's rows; anonymous sessions are refused there too).
grant insert, update, delete on public.saved_searches to authenticated;
grant insert, update, delete on public.listing_favourites to authenticated;
grant insert, update, delete on public.user_home to authenticated;
grant insert, update, delete on public.ownership_settings to authenticated;
grant delete on public.invites to authenticated;
grant delete on public.push_subscriptions to authenticated;
-- Alerts: only marking them read.
grant update (read_at) on public.alerts to authenticated;

-- Tables made by later migrations start without writes for the API roles.
alter default privileges in schema public
  revoke insert, update, delete, truncate, references, trigger
  on tables from anon, authenticated;
