-- The API roles may write only where the app does: anon nowhere, and a
-- signed-in account its own saved searches, favourites, home, colours, ownership
-- figures, the invites it deletes, its devices and the read mark of its
-- alerts. Everything else goes through functions or the collector.
do $$
declare
  v_table text;
  v_priv text;
  v_allowed text[] := array[
    'saved_searches:insert', 'saved_searches:update', 'saved_searches:delete',
    'listing_favourites:insert', 'listing_favourites:update', 'listing_favourites:delete',
    'user_home:insert', 'user_home:update', 'user_home:delete',
    'ownership_settings:insert', 'ownership_settings:update', 'ownership_settings:delete',
    'user_colours:insert', 'user_colours:update', 'user_colours:delete',
    'invites:delete', 'push_subscriptions:delete'];
begin
  for v_table in
    select c.relname from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p')
  loop
    foreach v_priv in array array['insert', 'update', 'delete', 'truncate', 'references', 'trigger'] loop
      assert not has_table_privilege('anon', 'public.' || v_table, v_priv),
        format('anon may %s on %s', v_priv, v_table);
      assert has_table_privilege('authenticated', 'public.' || v_table, v_priv)
               = (v_table || ':' || v_priv = any (v_allowed)),
        format('authenticated: %s on %s is not as expected', v_priv, v_table);
    end loop;
  end loop;

  assert has_table_privilege('anon', 'public.listings', 'select'), 'listings stay readable';
  assert has_column_privilege('authenticated', 'public.alerts', 'read_at', 'update');
  assert not has_column_privilege('authenticated', 'public.alerts', 'type', 'update');
  assert not has_column_privilege('authenticated', 'public.alerts', 'user_id', 'update');
end $$;

-- A table made by a later migration starts without writes for them.
create table public.grants_probe (id int);
do $$
begin
  assert not has_table_privilege('anon', 'public.grants_probe', 'insert');
  assert not has_table_privilege('authenticated', 'public.grants_probe', 'update');
  assert has_table_privilege('authenticated', 'public.grants_probe', 'select');
end $$;
drop table public.grants_probe;

-- The app's writes still work; others are refused.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000e1');
do $$
declare
  v_listing uuid;
begin
  insert into public.listings (source, source_listing_id, url, brand, model, price, seller_type)
  values ('manual', 'grants-1', 'https://example.com/g1', 'Yamaha', 'MT-07', 6000, 'private')
  returning id into v_listing;
  insert into public.alerts (user_id, listing_id, type) values
    ('00000000-0000-0000-0000-0000000000e1', v_listing, 'new_listing');
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  insert into public.saved_searches (name) values ('Teste');
  insert into public.listing_favourites (listing_id)
    select id from public.listings where source_listing_id = 'grants-1';
  update public.alerts set read_at = now() where true;
  assert (select count(*) from public.alerts where read_at is not null) = 1;
  begin
    update public.alerts set type = 'price_reduction' where true;
    raise exception 'an account changed an alert''s type';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.alerts where true;
    raise exception 'an account deleted alerts';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.listings set price = 1 where true;
    raise exception 'an account changed a listing';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.user_models (motorcycle_id, min_year)
      select id, 2020 from public.motorcycles limit 1;
    raise exception 'an account wrote user_models directly';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
