-- Invites, admins and accounts made through Supabase Auth's admin API
-- (the http stub records each request and answers from http_replies).
insert into auth.users (id, email, created_at, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', now() - interval '2 days', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', now() - interval '1 day', false),
  ('00000000-0000-0000-0000-0000000000f1', null, now(), true);
-- The migration ran before these users existed: make the owner admin as it
-- would have.
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-0000000000a1');

-- Not until the collector stored the access.
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
declare
  v_code text := public.create_invite('  Primo  ');
begin
  assert (select note from public.invites where code = v_code) = 'Primo';
  assert char_length(v_code) = 22 and v_code !~ '[+/=]', v_code;
  assert public.invite_status(v_code) = 'ok';
  begin
    perform public.redeem_invite(v_code, 'new@example.com', 'longenough');
    assert false, 'redeemed without service access';
  exception when sqlstate '55000' then null;
  end;
  assert public.invite_status(v_code) = 'ok';
end $$;

reset test.uid;
reset test.jwt;
select public.store_service_access('https://abc.supabase.co/', 'key-1');
select public.store_service_access('https://abc.supabase.co', 'key-2');
do $$
begin
  assert (select count(*) from vault.secrets where name in ('service_url', 'service_role_key')) = 2;
  assert (select secret from vault.secrets where name = 'service_url') = 'https://abc.supabase.co';
  assert (select secret from vault.secrets where name = 'service_role_key') = 'key-2';
end $$;

-- Redeeming makes a confirmed account and uses the invite up.
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
create temp table codes as select public.create_invite(null) as code;
reset test.uid;
reset test.jwt;

-- Auth commits the user in its own transaction before it answers.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000c1', 'new@example.com');
insert into extensions.http_replies values
  ('POST', 'https://abc.supabase.co/auth/v1/admin/users', 200,
   '{"id": "00000000-0000-0000-0000-0000000000c1", "email": "new@example.com"}');

-- An anonymous visitor.
set local test.uid = '00000000-0000-0000-0000-0000000000f1';
set local test.jwt = '{"is_anonymous": true}';
do $$
declare
  v_code text := (select code from codes);
  v_call record;
begin
  begin
    perform public.redeem_invite(v_code, 'not-an-email', 'longenough');
    assert false, 'bad email accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.redeem_invite(v_code, 'new@example.com', 'short');
    assert false, 'short password accepted';
  exception when sqlstate '22023' then null;
  end;
  assert (select count(*) from extensions.http_calls) = 0;

  assert public.redeem_invite(v_code, ' New@Example.com ', 'longenough')
         = '00000000-0000-0000-0000-0000000000c1';
  select * into v_call from extensions.http_calls;
  assert v_call.method = 'POST';
  assert v_call.content::jsonb = '{"email": "new@example.com", "password": "longenough",
                                   "email_confirm": true}'::jsonb, v_call.content;
  assert ('apikey', 'key-2')::extensions.http_header = any (v_call.headers);
  assert public.invite_status(v_code) = 'used';

  begin
    perform public.redeem_invite(v_code, 'other@example.com', 'longenough');
    assert false, 'used invite redeemed again';
  exception when sqlstate 'P0002' then null;
  end;
  assert public.invite_status('nope') = 'unknown';
end $$;

-- An email that already has an account; an expired invite.
update extensions.http_replies
set status = 422, content = '{"code": 422, "error_code": "email_exists", "msg": "taken"}';
reset test.uid;
reset test.jwt;
insert into public.invites (code, created_by) values
  ('fresh', '00000000-0000-0000-0000-0000000000a1');
insert into public.invites (code, created_by, expires_at) values
  ('old', '00000000-0000-0000-0000-0000000000a1', now() - interval '1 minute');
do $$
begin
  begin
    perform public.redeem_invite('fresh', 'friend@example.com', 'longenough');
    assert false, 'existing email accepted';
  exception when sqlstate '23505' then null;
  end;
  assert public.invite_status('fresh') = 'ok';
  assert public.invite_status('old') = 'expired';
  begin
    perform public.redeem_invite('old', 'x@example.com', 'longenough');
    assert false, 'expired invite redeemed';
  exception when sqlstate 'P0002' then null;
  end;
end $$;

-- Admins only: invites, the accounts list, admin access, removal.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  assert not public.is_admin();
  assert (select count(*) from public.invites) = 0, 'a non-admin reads invites';
  begin
    perform public.create_invite(null);
    assert false, 'a non-admin created an invite';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.admin_accounts();
    assert false, 'a non-admin listed the accounts';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.set_admin('00000000-0000-0000-0000-0000000000b1', true);
    assert false, 'a non-admin made itself admin';
  exception when sqlstate '42501' then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  assert public.is_admin();
  assert (select count(*) from public.invites) >= 3;
  -- Real accounts only, oldest first.
  assert (select array_agg(email order by created_at) from public.admin_accounts())
         = array['owner@example.com', 'friend@example.com', 'new@example.com'];
  assert (select is_admin and is_me from public.admin_accounts() where email = 'owner@example.com');
  assert not (select is_me from public.admin_accounts() where email = 'friend@example.com');

  perform public.set_admin('00000000-0000-0000-0000-0000000000b1', true);
  assert (select is_admin from public.admin_accounts() where email = 'friend@example.com');
  perform public.set_admin('00000000-0000-0000-0000-0000000000b1', false);
  assert not (select is_admin from public.admin_accounts() where email = 'friend@example.com');
  begin
    perform public.set_admin('00000000-0000-0000-0000-0000000000a1', false);
    assert false, 'an admin removed its own access';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.remove_account('00000000-0000-0000-0000-0000000000a1');
    assert false, 'an admin removed itself';
  exception when sqlstate '22023' then null;
  end;

  delete from public.invites where code = 'fresh';
  assert public.invite_status('fresh') = 'unknown';
end $$;
reset role;

-- Removing an account asks Auth to delete it and stops collecting the
-- models only it followed.
insert into public.motorcycles (brand, model, slug, min_year, is_active)
values ('Testbrand', 'Only B', 'testbrand-only-b', 2023, true);
insert into public.user_models (user_id, motorcycle_id, min_year)
select '00000000-0000-0000-0000-0000000000b1', id, 2023
from public.motorcycles where slug = 'testbrand-only-b';
truncate extensions.http_calls;
do $$
begin
  perform public.remove_account('00000000-0000-0000-0000-0000000000b1');
  assert (select method || ' ' || uri from extensions.http_calls)
         = 'DELETE https://abc.supabase.co/auth/v1/admin/users/00000000-0000-0000-0000-0000000000b1';
  assert not exists (select 1 from public.user_models
                     where user_id = '00000000-0000-0000-0000-0000000000b1');
  assert not (select is_active from public.motorcycles
              where slug = 'testbrand-only-b');
end $$;

-- Telegram gets only admins' alerts.
reset test.uid;
reset test.jwt;
do $$
declare
  v_listing uuid;
begin
  insert into public.listings (source, source_listing_id, url, brand, model, price, seller_type)
  values ('manual', 'acc-1', 'https://example.com/1', 'Yamaha', 'MT-07', 6000, 'private')
  returning id into v_listing;
  insert into public.alerts (user_id, listing_id, type) values
    ('00000000-0000-0000-0000-0000000000a1', v_listing, 'new_listing');
  insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000d1');
  insert into public.alerts (user_id, listing_id, type) values
    ('00000000-0000-0000-0000-0000000000d1', v_listing, 'new_listing');
  assert (select array_agg(to_telegram order by to_telegram desc)
          from public.pending_notifications(20)) = array[true, false];
end $$;
