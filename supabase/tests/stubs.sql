-- Stand-ins for what Supabase provides, so every migration applies to a
-- plain Postgres (CI and local): the API roles, the auth schema, and
-- pg_cron, pg_net, http and Vault (the runner skips their `create
-- extension`).
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
create table auth.users (id uuid primary key, is_anonymous boolean not null default false,
                         email varchar(255), created_at timestamptz default now(),
                         last_sign_in_at timestamptz);
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
create table vault.secrets (name text, secret text, id uuid primary key default gen_random_uuid());
create view vault.decrypted_secrets as select id, name, secret as decrypted_secret from vault.secrets;
create function vault.create_secret(new_secret text, new_name text default null,
                                    new_description text default '')
returns uuid language sql as $$
  insert into vault.secrets (name, secret) values (new_name, new_secret) returning id
$$;
create function vault.update_secret(secret_id uuid, new_secret text default null,
                                    new_name text default null,
                                    new_description text default null)
returns void language sql as $$
  update vault.secrets set secret = coalesce(new_secret, secret) where id = secret_id
$$;

-- The http extension (pgsql-http), synchronous: each request is recorded
-- in extensions.http_calls and answered by the first row a test put in
-- extensions.http_replies for its method and address (else 200 '{}').
create domain extensions.http_method as text;
create type extensions.http_header as (field varchar, value varchar);
create type extensions.http_request as (method extensions.http_method, uri varchar,
                                        headers extensions.http_header[],
                                        content_type varchar, content varchar);
create type extensions.http_response as (status integer, content_type varchar,
                                         headers extensions.http_header[], content varchar);
create table extensions.http_calls (method text, uri text, headers extensions.http_header[],
                                    content text);
create table extensions.http_replies (method text, uri text, status integer, content text);
create function extensions.http_header(field varchar, value varchar)
returns extensions.http_header language sql as $$ select row(field, value)::extensions.http_header $$;
create function extensions.http_set_curlopt(curlopt varchar, value varchar)
returns boolean language sql as $$ select true $$;
create function extensions.http(request extensions.http_request)
returns extensions.http_response language sql as $$
  insert into extensions.http_calls
  values (request.method, request.uri, request.headers, request.content);
  select row(coalesce(r.status, 200), 'application/json', null, coalesce(r.content, '{}'))
           ::extensions.http_response
  from (select 1) one
  left join lateral (select * from extensions.http_replies x
                     where x.method = request.method and x.uri = request.uri
                     limit 1) r on true
$$;

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
