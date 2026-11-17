-- "A minha mota" with any model (N.120): an owned bike keeps its model
-- collected from three years before the oldest owned year, and the last
-- one sold lets it go.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f3');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f3';
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  v_model uuid := public.bike_value_model('Kawasaki', 'Versys 650');
  v_other uuid := public.bike_value_model('Suzuki', 'V-Strom 650');
  v_bike uuid;
begin
  assert (select not is_active from public.motorcycles where id = v_model),
    'a model added from the app is followed by nobody';

  insert into public.owned_bikes (motorcycle_id, year)
  values (v_model, 2019) returning id into v_bike;
  assert (select is_active and min_year = 2016 and collected_since = now()
          from public.motorcycles where id = v_model),
    'an owned bike keeps its model collected from three years before';

  insert into public.owned_bikes (motorcycle_id, year) values (v_model, 2015);
  assert (select min_year = 2012 from public.motorcycles where id = v_model),
    'the oldest owned bike sets the first year';

  delete from public.owned_bikes where year = 2015 and motorcycle_id = v_model;
  assert (select is_active from public.motorcycles where id = v_model),
    'still owned';

  update public.owned_bikes set motorcycle_id = v_other where id = v_bike;
  assert (select not is_active and collected_since is null
          from public.motorcycles where id = v_model),
    'moved away: the old model is let go';
  assert (select is_active and min_year = 2016
          from public.motorcycles where id = v_other),
    'moved to: the new model is collected';

  delete from public.owned_bikes where id = v_bike;
  assert (select not is_active from public.motorcycles where id = v_other),
    'the last bike sold lets the model go';
end $$;

-- A followed model stays collected from its own first year.
reset role;
insert into public.user_models (user_id, motorcycle_id, min_year)
select '00000000-0000-0000-0000-0000000000f3', id, 2018
from public.motorcycles where model = 'MT-07';
select public.refresh_collected_model(id) from public.motorcycles where model = 'MT-07';
set local role authenticated;
do $$
declare
  v_mt07 uuid := (select id from public.motorcycles where model = 'MT-07');
  v_min integer := (select min_year from public.motorcycles where model = 'MT-07');
begin
  assert v_min = 2018, 'followed from 2018';
  insert into public.owned_bikes (motorcycle_id, year) values (v_mt07, v_min + 5);
  assert (select is_active and min_year = v_min
          from public.motorcycles where id = v_mt07),
    'an owned bike never narrows a followed model''s years';
end $$;
