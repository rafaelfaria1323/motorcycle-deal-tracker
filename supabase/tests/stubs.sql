-- Stand-ins for what Supabase provides, so every migration applies to a
-- plain Postgres (CI and local): the API roles, the auth schema, and
-- pg_cron, pg_net and Vault (the runner skips their `create extension`).
-- auth.uid() and auth.jwt() read the settings test.uid and test.jwt, so a
-- test acts as a user with `set local test.uid = '...'`.
-- Roles belong to the whole server, so they may exist from an earlier run.
do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema auth;
create table auth.users (id uuid primary key, is_anonymous boolean not null default false);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as
  $$ select coalesce(nullif(current_setting('test.jwt', true), ''), '{}')::jsonb $$;
create function auth.role() returns text language sql stable as
  $$ select current_user::text $$;
grant usage on schema auth to anon, authenticated, service_role;

create schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;

create schema cron;
create table cron.job (jobname text primary key, schedule text, command text);
create function cron.schedule(n text, s text, c text) returns bigint language sql as $$
  insert into cron.job values (n, s, c)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command;
  select 1::bigint
$$;

create schema net;
create table net.calls (url text, body jsonb, headers jsonb);
create function net.http_post(url text, body jsonb default '{}', params jsonb default '{}',
                              headers jsonb default '{}', timeout_milliseconds int default 5000)
returns bigint language sql as $$ insert into net.calls values (url, body, headers); select 42::bigint $$;

create schema vault;
create table vault.secrets (name text, secret text);
create view vault.decrypted_secrets as select name, secret as decrypted_secret from vault.secrets;

-- Supabase grants the API roles everything in public by default and lets
-- row level security (and the migrations' revokes) decide; do the same, so
-- access tests fail for the same reasons they would there.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to anon, authenticated, service_role;
