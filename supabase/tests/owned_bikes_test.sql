-- "A minha mota" (N.67): each account sees and changes only its own
-- bikes, anonymous sessions none, one bike per ad, and a pruned ad
-- leaves the bike.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f1'),
                                   ('00000000-0000-0000-0000-0000000000f2');
insert into public.listings (source, source_listing_id, url, brand, model, price, seller_type)
values ('manual', 'owned-1', 'https://example.com/o1', 'Yamaha', 'MT-07', 6000, 'private');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f1';
set local test.jwt = '{"is_anonymous": false}';
insert into public.owned_bikes (motorcycle_id, listing_id, year, price_paid, mileage_at_purchase)
select m.id, l.id, 2021, 5800, 12000
from public.motorcycles m, public.listings l
where m.model = 'MT-07' and l.source_listing_id = 'owned-1';

do $$
declare
  refused boolean;
begin
  assert (select bought_on = current_date from public.owned_bikes),
    'the purchase date starts at today';

  refused := false;
  begin
    insert into public.owned_bikes (motorcycle_id, listing_id, year)
    select motorcycle_id, listing_id, year from public.owned_bikes;
  exception when unique_violation then refused := true;
  end;
  assert refused, 'the same ad is bought once per account';

  -- "Comprei esta" again (the app upserts) updates the bike.
  insert into public.owned_bikes (motorcycle_id, listing_id, year, price_paid)
  select motorcycle_id, listing_id, year, 5700 from public.owned_bikes
  on conflict (user_id, listing_id) do update set price_paid = excluded.price_paid;
  assert (select count(*) = 1 and min(price_paid) = 5700 from public.owned_bikes),
    'buying the same ad again updates it';

  -- Bikes typed in have no ad, and there can be several.
  insert into public.owned_bikes (motorcycle_id, year)
  select id, 2019 from public.motorcycles where model = 'MT-07';
  insert into public.owned_bikes (motorcycle_id, year)
  select id, 2018 from public.motorcycles where model = 'MT-07';
  assert (select count(*) from public.owned_bikes) = 3, 'bikes without an ad';
  delete from public.owned_bikes where listing_id is null;

  refused := false;
  begin
    update public.owned_bikes set price_paid = -1 where true;
  exception when check_violation then refused := true;
  end;
  assert refused, 'a negative price is refused';

  update public.owned_bikes set price_paid = 5600 where true;
  assert (select price_paid from public.owned_bikes) = 5600, 'the owner edits it';
end $$;

-- Another account sees nothing and changes nothing.
set local test.uid = '00000000-0000-0000-0000-0000000000f2';
do $$
declare
  v_count integer;
begin
  assert (select count(*) from public.owned_bikes) = 0, 'another account sees none';
  delete from public.owned_bikes where true;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'another account deletes none';

  begin
    insert into public.owned_bikes (user_id, motorcycle_id, year)
    select '00000000-0000-0000-0000-0000000000f1', id, 2020
    from public.motorcycles limit 1;
    raise exception 'an account added a bike to another';
  exception when insufficient_privilege then null;
  end;
end $$;

-- An anonymous session can't keep bikes.
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  insert into public.owned_bikes (motorcycle_id, year)
  select id, 2020 from public.motorcycles limit 1;
  raise exception 'an anonymous session added a bike';
exception when insufficient_privilege then null;
end $$;

-- A pruned ad leaves the bike.
reset role;
delete from public.listings where source_listing_id = 'owned-1';
do $$
begin
  assert (select listing_id is null and price_paid = 5600 from public.owned_bikes),
    'the bike stays without its ad';
end $$;
