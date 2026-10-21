-- The database's size and its biggest tables, for admins only.
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.com', false),
  ('00000000-0000-0000-0000-0000000000b1', 'friend@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-0000000000a1');

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
begin
  begin
    perform public.database_usage();
    assert false, 'a non-admin read the database usage';
  exception when sqlstate '42501' then null;
  end;
end $$;

set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
declare
  v_usage jsonb := public.database_usage();
  v_tables jsonb := v_usage -> 'tables';
begin
  assert (v_usage ->> 'database_bytes')::bigint > 0, v_usage::text;
  assert jsonb_array_length(v_tables) = 5, v_tables::text;
  assert (v_tables -> 0 ->> 'bytes')::bigint >= (v_tables -> 4 ->> 'bytes')::bigint,
    'biggest first';
  assert (v_tables -> 0 ->> 'bytes')::bigint < (v_usage ->> 'database_bytes')::bigint;
end $$;
reset role;
