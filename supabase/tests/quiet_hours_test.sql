-- Quiet hours: alerts of an account in its quiet hours (Lisbon time; by
-- default 23:00 to 08:00) are left out of the pending notifications.
do $$
begin
  assert public.in_quiet_hours(23, 8, 23) and public.in_quiet_hours(23, 8, 0)
         and public.in_quiet_hours(23, 8, 7), 'quiet hours wrap midnight';
  assert not public.in_quiet_hours(23, 8, 8) and not public.in_quiet_hours(23, 8, 22),
    'the end hour is not quiet, nor the hour before the start';
  assert public.in_quiet_hours(13, 15, 14) and not public.in_quiet_hours(13, 15, 15)
         and not public.in_quiet_hours(13, 15, 12), 'quiet hours within a day';
end $$;

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000f1', false),
  ('00000000-0000-0000-0000-0000000000f2', false);

insert into public.listings (source, source_listing_id, url, brand, model, price, year)
values ('olx', 'q1', 'https://x/q1', 'Yamaha', 'MT-07', 6500, 2021);

insert into public.alerts (user_id, listing_id, type)
select u, l.id, 'new_listing'
from public.listings l,
     (values ('00000000-0000-0000-0000-0000000000f1'::uuid),
             ('00000000-0000-0000-0000-0000000000f2'::uuid)) v(u)
where l.source_listing_id = 'q1';

do $$
declare
  f1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  f2 constant uuid := '00000000-0000-0000-0000-0000000000f2';
begin
  -- Winter (UTC = Lisbon) and summer (UTC + 1): 07:30 UTC in July is
  -- 08:30 in Lisbon.
  assert public.account_quiet_at(f1, '2026-01-15 00:00+00'), 'the default is on at midnight';
  assert public.account_quiet_at(f1, '2026-01-15 07:30+00');
  assert not public.account_quiet_at(f1, '2026-07-15 07:30+00'), 'summer time is Lisbon''s';
  assert not public.account_quiet_at(f1, '2026-01-15 12:00+00');

  assert (select count(*) from public.pending_notifications(200, '2026-01-15 00:00+00')) = 0,
    'nobody''s alerts go at midnight by default';
  assert (select count(*) from public.pending_notifications(200, '2026-01-15 08:00+00')) = 2,
    'they go with the 08:00 run';
  assert (select count(*) from public.pending_notifications()) = 2,
    'without a time nobody is left out';

  insert into public.quiet_hours (user_id, enabled) values (f1, false);
  insert into public.quiet_hours (user_id, start_hour, end_hour) values (f2, 13, 15);
  assert (select array_agg(user_id)
          from public.pending_notifications(200, '2026-01-15 00:00+00')) = array[f1, f2],
    'switched off, or other hours: midnight is not quiet';
  assert (select array_agg(user_id)
          from public.pending_notifications(200, '2026-01-15 14:00+00')) = array[f1],
    'the account''s own hours hold its alerts';

  begin
    insert into public.quiet_hours (user_id, start_hour, end_hour)
    values (f1, 8, 8) on conflict (user_id) do update set start_hour = 8, end_hour = 8;
    raise exception 'equal hours were accepted';
  exception when check_violation then null;
  end;
  begin
    update public.quiet_hours set end_hour = 24 where user_id = f2;
    raise exception 'hour 24 was accepted';
  exception when check_violation then null;
  end;
  delete from public.quiet_hours where true;
end $$;

-- The owner manages its own row through the app's upsert.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  insert into public.quiet_hours (enabled, start_hour, end_hour) values (true, 22, 7)
  on conflict (user_id) do update
    set enabled = excluded.enabled, start_hour = excluded.start_hour,
        end_hour = excluded.end_hour;
  insert into public.quiet_hours (enabled, start_hour, end_hour) values (false, 22, 7)
  on conflict (user_id) do update set enabled = excluded.enabled;
  assert (select not enabled and start_hour = 22 and end_hour = 7 from public.quiet_hours),
    'the account saves its quiet hours';
  begin
    delete from public.quiet_hours where user_id = auth.uid();
    raise exception 'the app deleted quiet hours';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.account_quiet_at(auth.uid(), now());
    raise exception 'the app called account_quiet_at';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.pending_notifications(200, now());
    raise exception 'the app read pending notifications';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f2';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  assert not exists (select from public.quiet_hours), 'another account sees nothing';
  update public.quiet_hours set enabled = true
  where user_id = '00000000-0000-0000-0000-0000000000f1';
  begin
    insert into public.quiet_hours (user_id, enabled)
    values ('00000000-0000-0000-0000-0000000000f1', true);
    raise exception 'another account wrote the row';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    insert into public.quiet_hours (enabled) values (false);
    raise exception 'an anonymous visitor saved quiet hours';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$
begin
  assert (select not enabled from public.quiet_hours
          where user_id = '00000000-0000-0000-0000-0000000000f1'),
    'other accounts changed nothing';
  assert not has_table_privilege('anon', 'public.quiet_hours', 'select');
end $$;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000f1';
do $$
begin
  assert not exists (select from public.quiet_hours), 'account deletion removes its quiet hours';
end $$;
