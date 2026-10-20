-- Distance from the owner's home: place names matched loosely, km by the
-- straight line, null when a place is unknown or no home is set, and each
-- person's home is their own.
do $$
begin
  assert public.place_key('Santarém (Marvila), Santa Iria da Ribeira') = 'santarem';
  assert public.place_key('  Vila Nova de Gaia ') = 'vila nova de gaia';
  assert public.place_key('Póvoa-de-Varzim') = 'povoa de varzim';
  assert public.place_key('São João da Madeira') = 'sao joao da madeira';
  assert public.place_key('') is null and public.place_key(null) is null;

  assert (select count(*) from public.places) > 900, 'towns, municipalities and districts';
  assert (select count(*) from public.places
          where key in ('lisboa', 'porto', 'rio tinto', 'funchal', 'corvo',
                        'acores', 'madeira', 'braga', 'faro', 'evora')) = 10,
    'the big towns, the islands and district names are there';

  assert public.distance_between(41.1485, -8.611, 38.7251, -9.1498) between 270 and 280,
    'Porto to Lisboa is about 274 km in a straight line';
  assert public.distance_between(41.1485, -8.611, 41.1485, -8.611) = 0;
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000e1'),
                                   ('00000000-0000-0000-0000-0000000000e2');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price, location)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000, v.loc
from public.motorcycles m,
     (values ('near', 'Matosinhos'), ('far', 'Lisboa'), ('nowhere', 'Algures'), ('blank', null))
       v(sid, loc)
where m.slug = 'yamaha-mt-07';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e1';
insert into public.user_home (place_key) values ('porto');

do $$
declare
  d_near int;
  d_far int;
begin
  select public.distance_km(l) into d_near from public.listings l where source_listing_id = 'near';
  select public.distance_km(l) into d_far from public.listings l where source_listing_id = 'far';
  assert d_near between 3 and 10, format('Porto to Matosinhos, got %s', d_near);
  assert d_far between 270 and 280, format('Porto to Lisboa, got %s', d_far);
  assert (select public.distance_km(l) from public.listings l
          where source_listing_id = 'nowhere') is null, 'unknown place: no distance';
  assert (select public.distance_km(l) from public.listings l
          where source_listing_id = 'blank') is null, 'no location: no distance';
end $$;

-- A saved search "up to 50 km" matches only the listing near home.
insert into public.saved_searches (name, max_distance_km) values ('Perto', 50);
do $$
begin
  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches m
          join public.listings l on l.id = m.listing_id) = array['near'],
    'only the near listing matches';
end $$;
reset role;

-- The alerts (run as the owner) use the search owner's home.
do $$
begin
  assert (select count(*) from public.saved_search_matches) = 1,
    'the same match without a signed-in user';
end $$;

-- Another person has no home yet: no distances, and can't see or change e1's.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e2';
do $$
declare
  refused boolean := false;
begin
  assert (select count(*) from public.user_home) = 0, 'another person sees no home';
  assert (select public.distance_km(l) from public.listings l
          where source_listing_id = 'near') is null, 'no home: no distance';
  update public.user_home set place_key = 'faro';
  begin
    insert into public.user_home (user_id, place_key)
    values ('00000000-0000-0000-0000-0000000000e1', 'faro');
  exception when insufficient_privilege or unique_violation then refused := true;
  end;
  assert refused, 'a home for someone else is refused';
end $$;
reset role;

do $$
begin
  assert (select place_key from public.user_home
          where user_id = '00000000-0000-0000-0000-0000000000e1') = 'porto',
    'another person changed nothing';
end $$;

-- Places are readable by visitors (to pick a home), homes are not.
set local role anon;
do $$
begin
  assert (select count(*) from public.places) > 900, 'anon reads places';
end $$;
reset role;
