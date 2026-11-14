-- What changed since a favourite was last opened (N.97): the database
-- keeps the ad as it was when it became a favourite and each time its
-- owner opens it again, whatever the app sends.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000f7', false);

insert into public.listings (source, source_listing_id, url, brand, model, price, year, mileage, location)
values ('olx', 's1', 'https://x/s1', 'Yamaha', 'MT-07', 6500, 2021, 12000, 'Lisboa');

insert into public.listing_favourites (user_id, listing_id, seen_price)
select '00000000-0000-0000-0000-0000000000f7', id, 1
from public.listings where source_listing_id = 's1';

do $$
declare
  owner constant uuid := '00000000-0000-0000-0000-0000000000f7';
  r record;
begin
  select * into r from public.listing_favourites where user_id = owner;
  assert r.seen_at is not null, 'stamped when added';
  assert r.seen_price = 6500 and r.seen_mileage = 12000 and r.seen_status = 'active',
    format('the ad as it was, not what was sent: %s %s %s', r.seen_price, r.seen_mileage, r.seen_status);

  update public.listings set price = 6000, mileage = 9000, status = 'removed'
  where source_listing_id = 's1';

  -- Other edits keep the snapshot.
  update public.listing_favourites set note = 'Ligar' where user_id = owner;
  select * into r from public.listing_favourites where user_id = owner;
  assert r.seen_price = 6500 and r.seen_status = 'active', 'a note keeps what was seen';

  -- Opening it again takes the ad as it is now, at the database's time.
  update public.listing_favourites
     set seen_at = '2000-01-01', seen_price = 1
   where user_id = owner;
  select * into r from public.listing_favourites where user_id = owner;
  assert r.seen_at = now(), 'the database''s time';
  assert r.seen_price = 6000 and r.seen_mileage = 9000 and r.seen_status = 'removed',
    'seen again: the ad now';
end $$;

-- The owner can mark it seen through the API.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f7';
update public.listing_favourites set seen_at = now()
where listing_id = (select id from public.listings where source_listing_id = 's1');
reset role;
