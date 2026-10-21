-- Mais › "Estado da recolha" (admins): each run's problems, each site's
-- request budget and pause, a link to the GitHub run, and whether the
-- GitHub token that starts the runs still works and when it expires.

-- Written by report_run.dart: the error lines of a run that was not ok;
-- per site {"requests_today", "daily_limit", "paused_until"} from the
-- fetch state after the run; the GitHub Actions run's page.
alter table public.collector_runs
  add column problems text[] not null default '{}',
  add column sites jsonb not null default '{}'::jsonb,
  add column run_url text;

-- The last check of the Vault's github_dispatch_token (one row, no API
-- access): 'ok', 'missing' (not in the Vault) or 'refused' (GitHub said
-- no), GitHub's answer and the token's expiry from GitHub's
-- github-authentication-token-expiration header (none: never expires).
create table public.github_token_check (
  id          boolean primary key default true check (id),
  checked_at  timestamptz,
  state       text check (state in ('ok', 'missing', 'refused')),
  http_status integer,
  expires_at  timestamptz,
  warned_on   date
);

insert into public.github_token_check default values;

alter table public.github_token_check enable row level security;
revoke all on public.github_token_check from anon, authenticated;

-- Asks GitHub about the token (reading collect.yml needs the same
-- "Actions" permission as starting it) and stores the answer. Telegram is
-- told, at most once a day, when GitHub refuses it or it expires within
-- 14 days, so it is renewed before the runs stop.
create function public.check_github_token()
returns public.github_token_check
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token    text;
  v_response extensions.http_response;
  v_header   extensions.http_header;
  v_expires  timestamptz;
  v_row      public.github_token_check;
  v_message  text;
begin
  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s where s.name = 'github_dispatch_token';

  if v_token is null then
    update public.github_token_check
    set checked_at = now(), state = 'missing', http_status = null, expires_at = null
    returning * into v_row;
    return v_row;
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '10000');
  v_response := extensions.http((
    'GET',
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
      || '/actions/workflows/collect.yml',
    array[extensions.http_header('Authorization', 'Bearer ' || v_token),
          extensions.http_header('Accept', 'application/vnd.github+json'),
          extensions.http_header('X-GitHub-Api-Version', '2022-11-28'),
          extensions.http_header('User-Agent', 'motorcycle-deal-tracker')],
    null,
    null
  )::extensions.http_request);

  foreach v_header in array coalesce(v_response.headers, '{}') loop
    if lower(v_header.field) = 'github-authentication-token-expiration' then
      begin
        v_expires := v_header.value::timestamptz;
      exception when others then
        v_expires := null;
      end;
    end if;
  end loop;

  update public.github_token_check
  set checked_at = now(),
      state = case when v_response.status = 200 then 'ok' else 'refused' end,
      http_status = v_response.status,
      expires_at = v_expires
  returning * into v_row;

  if v_row.warned_on is distinct from current_date then
    if v_row.state = 'refused' then
      v_message := format(
        '🔑 O GitHub recusou o token que inicia as recolhas (HTTP %s). Sem ele '
        'as recolhas não começam: crie um novo e substitua-o no Vault do '
        'Supabase (docs/hosting.md).', v_row.http_status);
    elsif v_expires < now() + interval '14 days' then
      v_message := format(
        '🔑 O token do GitHub que inicia as recolhas expira a %s. Crie um novo '
        'e substitua-o no Vault do Supabase (docs/hosting.md).',
        to_char(v_expires at time zone 'Europe/Lisbon', 'DD/MM/YYYY'));
    end if;
    if v_message is not null and public.send_telegram(v_message) is not null then
      update public.github_token_check set warned_on = current_date
      returning * into v_row;
    end if;
  end if;
  return v_row;
end;
$$;

revoke all on function public.check_github_token() from public, anon, authenticated;

-- What "Estado da recolha" shows about the token, checked now.
create function public.github_token_status()
returns table (state text, http_status integer, expires_at timestamptz, checked_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.github_token_check;
begin
  perform public.require_admin();
  v_row := public.check_github_token();
  return query select v_row.state, v_row.http_status, v_row.expires_at, v_row.checked_at;
end;
$$;

revoke all on function public.github_token_status() from public, anon;
grant execute on function public.github_token_status() to authenticated;

-- Every morning (UTC), so an expiry is noticed even when nobody opens the
-- page.
select cron.schedule(
  'github-token-check',
  '7 8 * * *',
  $job$ select public.check_github_token() $job$
);
