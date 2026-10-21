-- GitHub's scheduler never started collect.yml (no scheduled run at all,
-- even hourly), so Postgres starts the workflows instead: pg_cron calls
-- GitHub's workflow_dispatch API through pg_net, with a token kept in the
-- Vault. The fetching rules are unchanged (the collector enforces them).
--
-- One-time setup by Rafael (never in a migration or a chat): a fine-grained
-- GitHub token with access to this repository only and "Actions: Read and
-- write", saved in Supabase's SQL editor with
--   select vault.create_secret('<token>', 'github_dispatch_token');
-- Until it exists the jobs only log a warning. GitHub's answers stay for a
-- few hours in net._http_response (201/204 = started).

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Starts a workflow of this repository on main; returns pg_net's request
-- id, or null when the token is missing.
create function public.dispatch_workflow(p_workflow text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  if p_workflow not in ('collect.yml', 'weekly-summary.yml') then
    raise exception 'unknown workflow %', p_workflow;
  end if;

  select s.decrypted_secret into token
  from vault.decrypted_secrets s
  where s.name = 'github_dispatch_token';

  if token is null then
    raise warning 'github_dispatch_token is not in the Vault; % not started',
      p_workflow;
    return null;
  end if;

  return net.http_post(
    url := 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/' || p_workflow || '/dispatches',
    body := '{"ref": "main"}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || token,
      'Accept', 'application/vnd.github+json',
      'Content-Type', 'application/json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent', 'motorcycle-deal-tracker'
    ),
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function public.dispatch_workflow(text)
  from public, anon, authenticated;

-- pg_cron runs in UTC. A job with the same name is replaced, so this is
-- safe to run again. collection_text.dart in the app mirrors the first one.
select cron.schedule(
  'collect-listings',
  '40 */4 * * *',
  $job$ select public.dispatch_workflow('collect.yml') $job$
);
select cron.schedule(
  'weekly-summary',
  '52 7 * * 1',
  $job$ select public.dispatch_workflow('weekly-summary.yml') $job$
);
