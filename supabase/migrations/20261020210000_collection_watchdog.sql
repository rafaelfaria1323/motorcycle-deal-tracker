-- Watchdog (11.4): the collector tells Telegram when a run fails, but a run
-- that never starts (expired github_dispatch_token, the collect job gone, an
-- Actions job dying before it records itself) says nothing. Every hour
-- Postgres checks the last recorded run: none for 9 hours (two missed
-- collections) sends one Telegram message, repeated once a day while it
-- lasts; the first run afterwards sends "voltaram a começar".
--
-- One-time setup by Rafael (never in a migration or a chat), in Supabase's
-- SQL editor, with the same values as the TELEGRAM_* repository secrets:
--   select vault.create_secret('<bot token>', 'telegram_bot_token');
--   select vault.create_secret('<chat id>', 'telegram_chat_id');
-- Until both exist the check only logs a warning.

-- One row: when the last "no runs" message was sent (null: none pending).
create table public.collection_watchdog (
  id        boolean primary key default true check (id),
  warned_at timestamptz
);
insert into public.collection_watchdog default values;

-- Nobody reads it through the API; only the functions below.
alter table public.collection_watchdog enable row level security;
revoke all on public.collection_watchdog from anon, authenticated;

-- Sends [p_text] to the owner's Telegram chat with pg_net; returns pg_net's
-- request id, or null when the Vault has no bot token or chat id.
create function public.send_telegram(p_text text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
  chat  text;
begin
  select s.decrypted_secret into token
  from vault.decrypted_secrets s where s.name = 'telegram_bot_token';
  select s.decrypted_secret into chat
  from vault.decrypted_secrets s where s.name = 'telegram_chat_id';

  if token is null or chat is null then
    raise warning 'telegram_bot_token or telegram_chat_id is not in the Vault; message not sent';
    return null;
  end if;

  return net.http_post(
    url := 'https://api.telegram.org/bot' || token || '/sendMessage',
    body := jsonb_build_object('chat_id', chat, 'text', p_text),
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function public.send_telegram(text)
  from public, anon, authenticated;

-- Returns the message sent, or null when there was nothing to say (or it
-- could not be sent: then it tries again at the next check). [p_now] is
-- for the tests.
create function public.check_collection_runs(p_now timestamptz default now())
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
  set warned_at = case when message like '✅%' then null else p_now end;
  return message;
end;
$$;

revoke all on function public.check_collection_runs(timestamptz)
  from public, anon, authenticated;

-- Hourly at minute 20, away from the collection (minute 40) and its
-- recording.
select cron.schedule(
  'collection-watchdog',
  '20 * * * *',
  $job$ select public.check_collection_runs() $job$
);
