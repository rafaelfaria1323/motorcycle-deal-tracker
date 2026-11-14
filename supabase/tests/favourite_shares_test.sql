-- Shared favourites (16.11): one more account sees the owner's list,
-- read only, through a link used once.
insert into auth.users (id, is_anonymous, email) values
  ('00000000-0000-0000-0000-00000000a001', false, 'owner@example.com'),
  ('00000000-0000-0000-0000-00000000a002', false, 'viewer@example.com'),
  ('00000000-0000-0000-0000-00000000a003', false, 'other@example.com'),
  ('00000000-0000-0000-0000-00000000a004', true, null);

insert into public.listings (source, source_listing_id, url, brand, model, price, year, mileage, location)
values ('olx', 'sh1', 'https://x/sh1', 'Yamaha', 'MT-07', 6500, 2021, 12000, 'Lisboa');

insert into public.listing_favourites (user_id, listing_id, note)
select '00000000-0000-0000-0000-00000000a001', id, 'Ligar ao vendedor'
from public.listings where source_listing_id = 'sh1';

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  owner constant uuid := '00000000-0000-0000-0000-00000000a001';
  viewer constant uuid := '00000000-0000-0000-0000-00000000a002';
  other constant uuid := '00000000-0000-0000-0000-00000000a003';
  v_code text;
  v_first text;
  r record;
  n int;
begin
  -- No direct access to the table.
  begin
    perform 1 from public.favourite_shares;
    assert false, 'the table is not readable';
  exception when insufficient_privilege then null;
  end;

  perform set_config('test.uid', owner::text, true);
  v_first := public.share_favourites();
  v_code := public.share_favourites();
  assert v_code <> v_first, 'a new link each time';
  select * into r from public.my_favourite_share();
  assert r.code = v_code and r.viewer_email is null
     and r.code_expires_at > now() + interval '13 days', 'the link waits';

  -- Own link refused.
  begin
    perform public.accept_favourite_share(v_code);
    assert false, 'own link refused';
  exception when invalid_parameter_value then null;
  end;

  -- Nothing shared yet.
  perform set_config('test.uid', viewer::text, true);
  select count(*) into n from public.shared_favourites(owner);
  assert n = 0, 'not shared yet';
  begin
    perform public.accept_favourite_share(v_first);
    assert false, 'the replaced link is refused';
  exception when no_data_found then null;
  end;

  assert public.accept_favourite_share(v_code) = owner, 'opens the owner''s list';
  select * into r from public.favourites_shared_with_me();
  assert r.owner_id = owner and r.owner_email = 'owner@example.com', 'listed';
  select * into r from public.shared_favourites(owner);
  assert r.note = 'Ligar ao vendedor', 'sees the notes';

  -- The link is used once.
  perform set_config('test.uid', other::text, true);
  begin
    perform public.accept_favourite_share(v_code);
    assert false, 'used once';
  exception when no_data_found then null;
  end;
  select count(*) into n from public.shared_favourites(owner);
  assert n = 0, 'others see nothing';

  -- The owner sees who sees it; a new link keeps the viewer until used.
  perform set_config('test.uid', owner::text, true);
  select * into r from public.my_favourite_share();
  assert r.viewer_email = 'viewer@example.com' and r.code is null, 'who sees it';
  v_code := public.share_favourites();
  perform set_config('test.uid', viewer::text, true);
  select count(*) into n from public.shared_favourites(owner);
  assert n = 1, 'still sees it until the new link is used';

  -- The viewer leaves.
  perform public.leave_shared_favourites(owner);
  select count(*) into n from public.shared_favourites(owner);
  assert n = 0, 'left';

  -- Another account takes the new link; the owner stops sharing.
  perform set_config('test.uid', other::text, true);
  perform public.accept_favourite_share(v_code);
  select count(*) into n from public.shared_favourites(owner);
  assert n = 1, 'the new viewer sees it';
  perform set_config('test.uid', owner::text, true);
  perform public.stop_sharing_favourites();
  perform set_config('test.uid', other::text, true);
  select count(*) into n from public.shared_favourites(owner);
  assert n = 0, 'stopped';
  select count(*) into n from public.favourites_shared_with_me();
  assert n = 0, 'no list left';
end $$;

-- Anonymous sessions can't share.
set local test.uid = '00000000-0000-0000-0000-00000000a004';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  perform public.share_favourites();
  assert false, 'anonymous refused';
exception when insufficient_privilege then null;
end $$;
reset role;
