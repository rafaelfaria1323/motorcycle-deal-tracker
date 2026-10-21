-- Supabase loads pg-safeupdate for requests through its API (PostgREST),
-- which refuses an UPDATE or DELETE without a WHERE clause, also inside a
-- security definer function. check_github_token() updated its one-row table
-- without one, so "Estado da recolha" (github_token_status, called by the
-- app) always said the token could not be checked; the daily pg_cron check
-- doesn't go through the API and worked. Both one-row tables now say
-- `where id`. tool/sql_lint.sh checks every function for this from now on.

create or replace function public.check_github_token()
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
    where id
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
  where id
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
      update public.github_token_check set warned_on = current_date where id
      returning * into v_row;
    end if;
  end if;
  return v_row;
end;
$$;

create or replace function public.check_collection_runs(p_now timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  last_run timestamptz;
  warned   timestamptz;
  message  text;
begin
  select max(r.started_at) into last_run from public.collector_runs r;
  -- No run ever recorded: a new project, nothing has broken yet.
  if last_run is null then
    return null;
  end if;

  select w.warned_at into warned from public.collection_watchdog w;

  if last_run < p_now - interval '9 hours' then
    if warned is not null and warned > p_now - interval '24 hours' then
      return null;
    end if;
    message :=
      '⚠️ Nenhuma recolha de anúncios começou nas últimas '
      || floor(extract(epoch from p_now - last_run) / 3600)::int
      || ' h (a última foi a '
      || to_char(last_run at time zone 'Europe/Lisbon', 'DD/MM "às" HH24:MI')
      || '). O token do GitHub no Supabase pode ter expirado ou o '
      || 'agendamento parou: veja "Scheduled runs" em docs/hosting.md.';
  elsif warned is not null then
    message := '✅ As recolhas de anúncios voltaram a começar.';
  else
    return null;
  end if;

  if public.send_telegram(message) is null then
    return null;
  end if;

  update public.collection_watchdog
  set warned_at = case when message like '✅%' then null else p_now end
  where id;
  return message;
end;
$$;
