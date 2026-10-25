insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000e2');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e1';
set local test.jwt = '{"is_anonymous": false}';

insert into public.listing_card_preferences default values;

do $$
declare
  invalid_fields text[];
  refused boolean;
begin
  assert (select visible_fields = array[
    'source', 'deal_score', 'price_change', 'year', 'mileage', 'location',
    'preferred_colour'
  ] from public.listing_card_preferences), 'defaults preserve the current card';

  insert into public.listing_card_preferences (visible_fields)
  values (array[
    'risk_score', 'seller_type', 'first_seen_at', 'colour', 'registrations',
    'service_book', 'origin', 'warranty_until', 'dealer_warranty_months',
    'seller_name', 'published_at', 'site_refreshed_at', 'status'
  ])
  on conflict (user_id) do update set visible_fields = excluded.visible_fields;
  assert (select visible_fields = array[
    'risk_score', 'seller_type', 'first_seen_at', 'colour', 'registrations',
    'service_book', 'origin', 'warranty_until', 'dealer_warranty_months',
    'seller_name', 'published_at', 'site_refreshed_at', 'status'
  ] from public.listing_card_preferences), 'all detail choices survive an upsert';

  foreach invalid_fields slice 1 in array array[
    array['description', 'year'], array['year', null]
  ] loop
    refused := false;
    begin
      update public.listing_card_preferences set visible_fields = invalid_fields
      where user_id = auth.uid();
    exception when check_violation then refused := true;
    end;
    assert refused, 'unknown fields and null elements are refused';
  end loop;

  refused := false;
  begin
    update public.listing_card_preferences
    set visible_fields = array[array['year', 'mileage']]
    where user_id = auth.uid();
  exception when check_violation then refused := true;
  end;
  assert refused, 'nested arrays are refused';

  refused := false;
  begin
    update public.listing_card_preferences set visible_fields = null
    where user_id = auth.uid();
  exception when not_null_violation then refused := true;
  end;
  assert refused, 'a null selection is refused';

  update public.listing_card_preferences set visible_fields = '{}'
  where user_id = auth.uid();
  assert (select visible_fields = '{}'::text[]
          from public.listing_card_preferences), 'all optional fields may be hidden';
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e2';
do $$
declare
  refused boolean := false;
begin
  assert (select count(*) from public.listing_card_preferences) = 0,
    'another account cannot read the choices';
  update public.listing_card_preferences set visible_fields = array['year']
  where user_id = '00000000-0000-0000-0000-0000000000e1';
  begin
    insert into public.listing_card_preferences (user_id)
    values ('00000000-0000-0000-0000-0000000000e1');
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'another account cannot save these choices';
  insert into public.listing_card_preferences (visible_fields) values (array['year']);
end $$;
reset role;

-- An anonymous session has the authenticated role too.
set local role authenticated;
set local test.jwt = '{"is_anonymous": true}';
do $$
declare
  refused boolean := false;
begin
  assert (select count(*) from public.listing_card_preferences) = 0,
    'an anonymous session sees no preferences';
  begin
    insert into public.listing_card_preferences (visible_fields) values ('{}')
    on conflict (user_id) do update set visible_fields = excluded.visible_fields;
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'an anonymous session cannot save preferences';
end $$;
reset role;

do $$
begin
  assert (select visible_fields = '{}'::text[] from public.listing_card_preferences
          where user_id = '00000000-0000-0000-0000-0000000000e1'),
    'another account changed nothing';
  assert not has_table_privilege('anon', 'public.listing_card_preferences', 'select'),
    'visitors without a session have no read grant';
  assert not has_table_privilege('authenticated', 'public.listing_card_preferences', 'delete'),
    'resetting uses the ordinary save, not a delete';
end $$;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000e1';
do $$
begin
  assert not exists (select from public.listing_card_preferences
                    where user_id = '00000000-0000-0000-0000-0000000000e1'),
    'account deletion removes its preferences';
end $$;
