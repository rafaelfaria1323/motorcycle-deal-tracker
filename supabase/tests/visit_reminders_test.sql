-- Visit planning (N.65): a favourite's visit is reminded once, the day
-- before (within 24 hours), outside the account's quiet hours, and again
-- when the visit is moved.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', false),
  ('00000000-0000-0000-0000-0000000000e2', false);

insert into public.listings (source, source_listing_id, url, brand, model, price, year, location)
values ('olx', 'v1', 'https://x/v1', 'Yamaha', 'MT-07', 6500, 2021, 'Lisboa'),
       ('olx', 'v2', 'https://x/v2', 'Honda', 'CB650R', 7200, 2020, 'Porto');

insert into public.listing_favourites (user_id, listing_id, visit_at)
select '00000000-0000-0000-0000-0000000000e1', id,
       case source_listing_id
         when 'v1' then '2026-01-16 10:00+00'::timestamptz
         else '2026-01-20 10:00+00'::timestamptz end
from public.listings where source_listing_id in ('v1', 'v2');

insert into public.listing_favourites (user_id, listing_id, visit_at)
select '00000000-0000-0000-0000-0000000000e2', id, '2026-01-15 18:30+00'
from public.listings where source_listing_id = 'v2';

do $$
declare
  v1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  v2 constant uuid := '00000000-0000-0000-0000-0000000000e2';
  r record;
  n integer;
begin
  -- 12:00 on the 15th: v1's visit tomorrow at 10:00 and v2's today at
  -- 18:30; v1's other one, five days away, waits.
  select count(*) into n from public.pending_visit_reminders('2026-01-15 12:00+00');
  assert n = 2, format('two visits within 24 hours, got %s', n);

  select * into r from public.pending_visit_reminders('2026-01-15 12:00+00')
  where user_id = v1;
  assert r.visit_day = 1 and r.visit_time = '10:00', 'tomorrow at 10:00';
  assert r.brand = 'Yamaha' and r.model = 'MT-07' and r.year = 2021
         and r.price = 6500 and r.location = 'Lisboa' and r.is_live, 'the bike';

  select * into r from public.pending_visit_reminders('2026-01-15 12:00+00')
  where user_id = v2;
  assert r.visit_day = 0 and r.visit_time = '18:30', 'today at 18:30';

  -- Summer: 09:00 UTC is 10:00 in Lisbon.
  update public.listing_favourites set visit_at = '2026-07-16 09:00+00'
  where user_id = v1 and visit_at = '2026-01-16 10:00+00';
  select * into r from public.pending_visit_reminders('2026-07-15 12:00+00')
  where user_id = v1;
  assert r.visit_time = '10:00', 'Lisbon''s summer time';
  update public.listing_favourites set visit_at = '2026-01-16 10:00+00'
  where user_id = v1 and visit_at = '2026-07-16 09:00+00';

  -- Midnight is in the default quiet hours: nothing goes then.
  assert not exists (select 1 from public.pending_visit_reminders('2026-01-16 00:00+00')),
    'quiet hours hold the reminders';

  -- Marked once; a second mark and a mark for another time do nothing.
  assert public.mark_visit_reminded(v1,
    (select id from public.listings where source_listing_id = 'v1'),
    '2026-01-16 10:00+00'), 'marked';
  assert not public.mark_visit_reminded(v1,
    (select id from public.listings where source_listing_id = 'v1'),
    '2026-01-16 10:00+00'), 'marked only once';
  assert not public.mark_visit_reminded(v2,
    (select id from public.listings where source_listing_id = 'v2'),
    '2026-01-15 19:00+00'), 'a visit moved meanwhile is not marked';
  assert not exists (select 1 from public.pending_visit_reminders('2026-01-15 14:00+00')
                     where user_id = v1), 'a reminded visit is not reminded again';

  -- Moving the visit reminds again; saving the same time does not.
  update public.listing_favourites set note = 'Ligar antes'
  where user_id = v1 and visit_at = '2026-01-16 10:00+00';
  assert (select visit_reminded_at is not null from public.listing_favourites
          where user_id = v1 and visit_at = '2026-01-16 10:00+00'), 'other edits keep it';
  update public.listing_favourites set visit_at = '2026-01-16 11:00+00'
  where user_id = v1 and visit_at = '2026-01-16 10:00+00';
  assert exists (select 1 from public.pending_visit_reminders('2026-01-15 14:00+00')
                 where user_id = v1 and visit_time = '11:00'), 'a moved visit is reminded again';

  -- A gone ad is still reminded, saying so.
  update public.listings set status = 'removed' where source_listing_id = 'v1';
  assert (select not is_live from public.pending_visit_reminders('2026-01-15 14:00+00')
          where user_id = v1), 'the ad is gone';

  -- Past visits are never reminded.
  assert not exists (select 1 from public.pending_visit_reminders('2026-01-16 12:00+00')
                     where user_id = v1), 'a visit already past';
end $$;

-- The owner sets and clears the visit; the functions are the collector's.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e2';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  update public.listing_favourites set visit_at = '2026-02-01 15:00+00'
  where listing_id = (select id from public.listings where source_listing_id = 'v2');
  assert (select visit_at from public.listing_favourites
          where listing_id = (select id from public.listings where source_listing_id = 'v2'))
         = '2026-02-01 15:00+00', 'the owner sets its visit';
  begin
    perform public.pending_visit_reminders(now());
    raise exception 'an account read the reminders';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.mark_visit_reminded(auth.uid(), gen_random_uuid(), now());
    raise exception 'an account marked a reminder';
  exception when insufficient_privilege then null;
  end;
end $$;
