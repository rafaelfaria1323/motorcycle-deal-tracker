-- "A minha mota" with any model (N.120), collected only when asked
-- (N.121): owning a bike of a model nobody follows doesn't start
-- collecting it, and never changes a followed model's years.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f3');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f3';
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  v_model uuid := public.bike_value_model('Kawasaki', 'Versys 650');
  v_bike uuid;
begin
  assert (select not is_active from public.motorcycles where id = v_model),
    'a model added from the app is followed by nobody';

  insert into public.owned_bikes (motorcycle_id, year)
  values (v_model, 2019) returning id into v_bike;
  assert (select not is_active and collected_since is null
          from public.motorcycles where id = v_model),
    'owning a bike starts no collection';

  delete from public.owned_bikes where id = v_bike;
  assert (select not is_active from public.motorcycles where id = v_model),
    'still not collected';
end $$;

-- A followed model keeps its own first year.
reset role;
insert into public.user_models (user_id, motorcycle_id, min_year)
select '00000000-0000-0000-0000-0000000000f3', id, 2018
from public.motorcycles where model = 'MT-07';
select public.refresh_collected_model(id) from public.motorcycles where model = 'MT-07';
set local role authenticated;
do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where model = 'MT-07');
begin
  insert into public.owned_bikes (motorcycle_id, year) values (v_mt07, 2012);
  assert (select is_active and min_year = 2018
          from public.motorcycles where id = v_mt07),
    'an owned bike never changes a followed model''s years';
end $$;

-- No trigger left on owned_bikes that refreshes collection.
do $$
begin
  assert not exists (
    select 1 from pg_catalog.pg_trigger
    where tgname = 'owned_bikes_collect_model'
  ), 'N.120''s trigger is gone';
end $$;
