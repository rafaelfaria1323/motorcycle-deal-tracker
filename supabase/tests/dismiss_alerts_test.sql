insert into auth.users (id, is_anonymous)
values ('00000000-0000-0000-0000-0000000000a1', false),
       ('00000000-0000-0000-0000-0000000000a2', false),
       ('00000000-0000-0000-0000-0000000000a3', true);

insert into public.listings (source, source_listing_id, url, brand, model, price)
values ('manual', 'dismiss-alert', 'https://example.com/dismiss', 'Yamaha', 'MT-07', 6400);

insert into public.alerts (id, user_id, listing_id, type, dismissed_at, read_at, notified_at)
select v.id::uuid, v.owner::uuid, l.id, v.type::public.alert_type,
       v.dismissed::timestamptz, v.read::timestamptz, v.notified::timestamptz
from public.listings l,
     (values
       ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
        'new_listing', null, null, null),
       ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1',
        'price_reduction', '2026-10-20T12:00:00Z', '2026-10-19T12:00:00Z', '2026-10-19T13:00:00Z'),
       ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a2',
        'new_listing', null, null, null),
       ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a3',
        'new_listing', null, null, null)
     ) v(id, owner, type, dismissed, read, notified)
where l.source_listing_id = 'dismiss-alert';

do $$
begin
  assert has_function_privilege('authenticated', 'public.dismiss_alert(uuid)', 'execute');
  assert not has_function_privilege('anon', 'public.dismiss_alert(uuid)', 'execute');
  assert not has_column_privilege('authenticated', 'public.alerts', 'dismissed_at', 'update');
  assert not has_column_privilege('authenticated', 'public.alerts', 'notified_at', 'update');
  assert not has_table_privilege('authenticated', 'public.alerts', 'delete');
  assert exists (select 1 from public.pending_notifications()
                 where alert_id = '10000000-0000-0000-0000-000000000001');
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  perform public.dismiss_alert('10000000-0000-0000-0000-000000000001');
  perform public.dismiss_alert('10000000-0000-0000-0000-000000000001');
  assert (select dismissed_at = now() and read_at = now() and notified_at = now()
          from public.alerts where id = '10000000-0000-0000-0000-000000000001'),
    'dismissal retains the event, clears unread counts and handles pending pushes';
  assert (select count(*) from public.alerts where dismissed_at is null) = 0,
    'the owner has no visible alerts left and cannot read another account''s alerts';

  perform public.dismiss_alert('10000000-0000-0000-0000-000000000002');
  assert (select dismissed_at = '2026-10-20T12:00:00Z'::timestamptz
                 and read_at = '2026-10-19T12:00:00Z'::timestamptz
                 and notified_at = '2026-10-19T13:00:00Z'::timestamptz
          from public.alerts where id = '10000000-0000-0000-0000-000000000002'),
    'repeating dismissal preserves every existing timestamp';

  begin
    perform public.dismiss_alert('10000000-0000-0000-0000-000000000003');
    raise exception 'another account''s alert was dismissed';
  exception when no_data_found then null;
  end;
  begin
    perform public.dismiss_alert('10000000-0000-0000-0000-000000000099');
    raise exception 'a missing alert was accepted';
  exception when no_data_found then null;
  end;
  begin
    perform public.dismiss_alert(null);
    raise exception 'a null alert was accepted';
  exception when no_data_found then null;
  end;
  begin
    update public.alerts set dismissed_at = null
    where id = '10000000-0000-0000-0000-000000000001';
    raise exception 'dismissal was changed without the RPC';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a3';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.dismiss_alert('10000000-0000-0000-0000-000000000004');
    raise exception 'an anonymous session dismissed an alert';
  exception when insufficient_privilege then null;
  end;
end $$;

set local test.uid = '';
set local test.jwt = '{}';
do $$
begin
  begin
    perform public.dismiss_alert('10000000-0000-0000-0000-000000000001');
    raise exception 'a session without an account dismissed an alert';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$
begin
  assert (select count(*) from public.alerts) = 4, 'no event history was deleted';
  assert (select count(*) from public.alerts where dismissed_at is null) = 2,
    'other accounts and anonymous alerts were untouched';
  assert not exists (select 1 from public.pending_notifications()
                     where alert_id = '10000000-0000-0000-0000-000000000001'),
    'the dismissed alert is no longer pending delivery';
  assert exists (select 1 from public.pending_notifications()
                 where alert_id = '10000000-0000-0000-0000-000000000003'),
    'the other account''s notification remains pending';

  begin
    insert into public.alerts (user_id, listing_id, type)
    select '00000000-0000-0000-0000-0000000000a1', id, 'new_listing'
    from public.listings where source_listing_id = 'dismiss-alert';
    raise exception 'dismissing an alert allowed the same event to be generated again';
  exception when unique_violation then null;
  end;
end $$;

-- A deleted alert brings none of the listing's later news (removed, back
-- on the market); an alert still shown does, also beside a deleted one.
insert into auth.users (id, is_anonymous)
values ('00000000-0000-0000-0000-0000000000b1', false),  -- deleted its alert
       ('00000000-0000-0000-0000-0000000000b2', false),  -- kept it
       ('00000000-0000-0000-0000-0000000000b3', false);  -- deleted one of two

insert into public.listings (source, source_listing_id, url, brand, model, price,
                             status, last_checked_at, first_seen_at)
values ('olx', 'dismiss-gone', 'https://x/dismiss-gone', 'Yamaha', 'MT-07', 7000,
        'removed', now(), now() - interval '30 days'),
       ('olx', 'dismiss-back', 'https://x/dismiss-back', 'Yamaha', 'MT-07', 6800,
        'active', now(), now() - interval '1 day');
update public.listings b
set relisted_from = g.id, relisted_price = g.price
from public.listings g
where b.source_listing_id = 'dismiss-back' and g.source_listing_id = 'dismiss-gone';

insert into public.saved_searches (user_id, name, is_active, notify_listing_removed)
select u, 'MT', true, true
from unnest(array['00000000-0000-0000-0000-0000000000b1',
                  '00000000-0000-0000-0000-0000000000b2',
                  '00000000-0000-0000-0000-0000000000b3']::uuid[]) u;

insert into public.alerts (user_id, saved_search_id, listing_id, type, dismissed_at,
                           price_history_id)
select s.user_id, s.id, l.id, v.type::public.alert_type, v.dismissed::timestamptz,
       null
from public.saved_searches s
join (values ('00000000-0000-0000-0000-0000000000b1'::uuid, 'new_listing', '2026-10-20T12:00:00Z'),
             ('00000000-0000-0000-0000-0000000000b2'::uuid, 'new_listing', null),
             ('00000000-0000-0000-0000-0000000000b3'::uuid, 'new_listing', '2026-10-20T12:00:00Z'),
             ('00000000-0000-0000-0000-0000000000b3'::uuid, 'excellent_opportunity', null)
     ) v(owner, type, dismissed) on v.owner = s.user_id
cross join public.listings l
where l.source_listing_id = 'dismiss-gone';

do $$
begin
  assert public.generate_listing_removed_alerts() = 2, 'b2 and b3 only';
  assert public.generate_back_on_market_alerts() = 2, 'b2 and b3 only';
  assert not exists (select 1 from public.alerts
                     where user_id = '00000000-0000-0000-0000-0000000000b1'
                       and type in ('listing_removed', 'back_on_market')),
    'the account that deleted its only alert hears nothing more';
  assert (select count(*) from public.alerts
          where user_id in ('00000000-0000-0000-0000-0000000000b2',
                            '00000000-0000-0000-0000-0000000000b3')
            and type in ('listing_removed', 'back_on_market')) = 4,
    'an alert still shown keeps the follow-ups';
end $$;
