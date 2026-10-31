-- "Eliminar os lidos" (F.6): every read alert of the caller is hidden, as
-- dismiss_alert hides one; unread ones, other accounts' and the history stay.
insert into auth.users (id, is_anonymous)
values ('00000000-0000-0000-0000-0000000000a1', false),
       ('00000000-0000-0000-0000-0000000000a2', false),
       ('00000000-0000-0000-0000-0000000000a3', true);

insert into public.listings (source, source_listing_id, url, brand, model, price)
values ('manual', 'dismiss-read', 'https://example.com/dismiss-read', 'Yamaha', 'MT-07', 6400);

insert into public.alerts (id, user_id, listing_id, type, dismissed_at, read_at, notified_at)
select v.id::uuid, v.owner::uuid, l.id, v.type::public.alert_type,
       v.dismissed::timestamptz, v.read::timestamptz, v.notified::timestamptz
from public.listings l,
     (values
       -- a1: read and pushed, read but never pushed, unread, already deleted
       ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
        'new_listing', null, '2026-10-19T12:00:00Z', '2026-10-19T11:00:00Z'),
       ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1',
        'excellent_opportunity', null, '2026-10-19T12:00:00Z', null),
       ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1',
        'price_reduction', null, null, null),
       ('20000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1',
        'listing_removed', '2026-10-20T12:00:00Z', '2026-10-19T12:00:00Z', '2026-10-19T11:00:00Z'),
       -- a2's read alert is not a1's to delete
       ('20000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a2',
        'new_listing', null, '2026-10-19T12:00:00Z', null),
       ('20000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a3',
        'new_listing', null, '2026-10-19T12:00:00Z', null)
     ) v(id, owner, type, dismissed, read, notified)
where l.source_listing_id = 'dismiss-read';

do $$
begin
  assert has_function_privilege('authenticated', 'public.dismiss_read_alerts()', 'execute');
  assert not has_function_privilege('anon', 'public.dismiss_read_alerts()', 'execute');
  assert not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'alerts'
                       and cmd = 'DELETE'),
    'no delete policy outlives the delete grant';
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
declare
  n integer;
begin
  n := public.dismiss_read_alerts();
  assert n = 2, format('the two read alerts shown, got %s', n);
  assert (select array_agg(id order by id) from public.alerts where dismissed_at is null)
         = array['20000000-0000-0000-0000-000000000003']::uuid[],
    'only the unread alert is left';
  assert (select dismissed_at = now() and notified_at = '2026-10-19T11:00:00Z'::timestamptz
          from public.alerts where id = '20000000-0000-0000-0000-000000000001'),
    'a pushed alert keeps when it was pushed';
  assert (select dismissed_at = now() and notified_at = now()
          and read_at = '2026-10-19T12:00:00Z'::timestamptz
          from public.alerts where id = '20000000-0000-0000-0000-000000000002'),
    'a deleted alert is never pushed afterwards';
  assert (select dismissed_at = '2026-10-20T12:00:00Z'::timestamptz
          from public.alerts where id = '20000000-0000-0000-0000-000000000004'),
    'an alert deleted before keeps its date';
  assert public.dismiss_read_alerts() = 0, 'nothing more to delete';
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a3';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.dismiss_read_alerts();
    raise exception 'an anonymous session deleted alerts';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$
begin
  assert (select count(*) from public.alerts) = 6, 'no event history was deleted';
  assert (select dismissed_at is null from public.alerts
          where id = '20000000-0000-0000-0000-000000000005'),
    'another account''s read alert stays';
  assert (select dismissed_at is null from public.alerts
          where id = '20000000-0000-0000-0000-000000000006'),
    'the anonymous session''s alert stays';
  assert not exists (select 1 from public.pending_notifications()
                     where alert_id = '20000000-0000-0000-0000-000000000002'),
    'the deleted alert is no longer waiting to be pushed';
end $$;
