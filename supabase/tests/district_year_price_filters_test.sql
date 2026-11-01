-- Districts (F.11, 1.6): every place has one; a listing's district comes
-- from its place name, so "Porto" no longer finds "Porto de Mós". Saved
-- searches match a district, a maximum year and a minimum price (1.7).
do $$
begin
  assert public.place_district('Porto') = 'Porto', 'a district capital';
  assert public.place_district('Porto de Mós') = 'Leiria', 'not Porto';
  assert public.place_district('Maia') = 'Porto', 'a town of the district';
  assert public.place_district('Matosinhos, Porto') = 'Porto', 'text after a comma';
  assert public.place_district('Funchal') = 'Madeira', 'an autonomous region';
  assert public.place_district('Ponta Delgada') = 'Açores', 'the Azores';
  assert public.place_district('Lisboa') = 'Lisboa', 'Lisbon';
  assert public.place_district('Nenhures') is null, 'an unknown place';
  assert public.place_district(null) is null, 'no place';
  assert (select count(distinct district) from public.places) = 20,
    '18 districts and two regions';
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000d1');
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, 2000 from auth.users u cross join public.motorcycles m
where m.is_active;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, year, location)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.price, v.year, v.place
from public.motorcycles m,
     (values ('maia-2018',   5000, 2018, 'Maia'),
             ('mos-2018',    5000, 2018, 'Porto de Mós'),
             ('porto-2022',  9000, 2022, 'Porto'),
             ('porto-1eur',     1, 2018, 'Porto'),
             ('nowhere',     6000, null, null)) v(sid, price, year, place)
where m.slug = 'yamaha-mt-07';

do $$
begin
  assert (select array_agg(public.district(l) order by l.source_listing_id)
          from public.listings l where l.source_listing_id in ('maia-2018', 'mos-2018'))
         = array['Porto', 'Leiria'], 'the computed field';
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000d1';
insert into public.saved_searches (name, district, max_year, min_price)
values ('Porto', 'Porto', null, null),
       ('Até 2020', null, 2020, null),
       ('Desde 4000', null, null, 4000),
       ('Tudo', 'Porto', 2020, 4000);
do $$
declare
  refused boolean := false;
  function_names text[];
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Porto') = array['maia-2018', 'porto-1eur', 'porto-2022'],
    'the district, not the words';
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Até 2020') = array['maia-2018', 'mos-2018', 'porto-1eur'],
    'a maximum year; none without a year';
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Desde 4000') = array['maia-2018', 'mos-2018', 'nowhere', 'porto-2022'],
    'a minimum price; never a placeholder price';
  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Tudo') = array['maia-2018'], 'all three together';

  begin
    insert into public.saved_searches (name, district) values ('x', 'Galiza');
  exception when check_violation then refused := true;
  end;
  assert refused, 'an unknown district is refused';
end $$;
reset role;
