-- No run for 9 hours sends one Telegram message (again after a day), the
-- next run sends the recovery; nothing without the Vault secrets.
do $$
declare
  msg text;
begin
  assert public.check_collection_runs() is null, 'no run ever: nothing to say';

  insert into public.collector_runs (started_at, status)
  values (now() - interval '10 hours', 'ok');

  assert public.check_collection_runs() is null, 'without the secrets nothing is sent';
  assert (select warned_at from public.collection_watchdog) is null,
    'and nothing is marked as sent';

  insert into vault.secrets values ('telegram_bot_token', 'tok'), ('telegram_chat_id', '42');

  msg := public.check_collection_runs();
  assert msg like '⚠️ Nenhuma recolha de anúncios começou nas últimas 10 h (a última foi a %',
    format('the warning, got %s', msg);
  assert (select count(*) from net.calls
          where url = 'https://api.telegram.org/bottok/sendMessage'
            and body = jsonb_build_object('chat_id', '42', 'text', msg)) = 1,
    'sent to the chat through pg_net';
  assert (select warned_at from public.collection_watchdog) = now(), 'marked as sent';

  assert public.check_collection_runs(now() + interval '23 hours') is null,
    'not repeated within a day';
  assert public.check_collection_runs(now() + interval '25 hours') like '⚠️%35 h%',
    'repeated after a day';

  insert into public.collector_runs (started_at, status) values (now(), 'failed');
  assert public.check_collection_runs() = '✅ As recolhas de anúncios voltaram a começar.',
    'the next run is a recovery, whatever its status';
  assert (select warned_at from public.collection_watchdog) is null, 'cleared';
  assert public.check_collection_runs() is null, 'the recovery is sent once';
  assert (select count(*) from net.calls) = 3, 'three messages in all';

  assert exists (select from cron.job where jobname = 'collection-watchdog'
                 and schedule = '20 * * * *'), 'scheduled hourly';
end $$;

-- The app can't read the watchdog or send messages.
set local role authenticated;
do $$
begin
  begin
    perform public.send_telegram('x');
    assert false, 'send_telegram is not callable from the app';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.collection_watchdog;
    assert false, 'the watchdog table is not readable';
  exception when insufficient_privilege then null;
  end;
end $$;
