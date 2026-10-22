-- Models per account: each account follows its own models from its own
-- year; the collection runs whatever any account follows, from the
-- earliest year; listings, Ofertas and saved searches follow each
-- account's list; anonymous sessions see everything collected.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false),  -- A
  ('00000000-0000-0000-0000-0000000000b1', false),  -- B
  ('00000000-0000-0000-0000-0000000000c1', true);   -- anonymous

-- Start from nothing collected.
update public.motorcycles set is_active = false;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, year, price)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.year, 7000
from (values ('mt07-2021', 'yamaha-mt-07', 2021), ('mt07-2026', 'yamaha-mt-07', 2026),
             ('cbr-2025', 'honda-cbr650r', 2025), ('cbr-2019', 'honda-cbr650r', 2019))
       v(sid, slug, year)
join public.motorcycles m on m.slug = v.slug;

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';

-- A: MT-07 from 2020 and CBR650R from 2025.
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  cbr uuid := (select id from public.motorcycles where slug = 'honda-cbr650r');
begin
  assert not exists (select 1 from public.motorcycles m where public.tracked_by_me(m)),
    'a new account follows nothing';
  perform public.set_model_tracked(mt07, true);
  perform public.set_model_min_year(mt07, 2020);
  perform public.set_model_min_year(cbr, 2025);
  assert (select not is_active from public.motorcycles where id = cbr),
    'a year alone does not follow the model';
  perform public.set_model_tracked(cbr, true);
  assert (select is_active and min_year = 2025 from public.motorcycles where id = cbr),
    'followed by A: collected from A''s year';
  assert (select array_agg(source_listing_id order by source_listing_id)
          from public.listings l where public.in_my_models(l))
         = array['cbr-2025', 'mt07-2021', 'mt07-2026'], 'A sees its models from its years';
end $$;

-- B: MT-07 from 2026.
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
begin
  perform public.set_model_tracked(mt07, true);
  perform public.set_model_min_year(mt07, 2026);
  assert (select min_year from public.motorcycles where id = mt07) = 2020,
    'collected from the earliest year of the two';
  assert (select array_agg(m.slug) from public.motorcycles m where public.tracked_by_me(m))
         = array['yamaha-mt-07'], 'B follows only the MT-07';
  assert (select public.my_min_year(m) from public.motorcycles m where id = mt07) = 2026,
    'B''s own year';
  assert (select array_agg(source_listing_id)
          from public.listings l where public.in_my_models(l)) = array['mt07-2026'],
    'B sees only its MT-07s from 2026';
  assert (select count(*) from public.user_models) = 1, 'B reads only its own choices';
  assert not public.owner_tracks('00000000-0000-0000-0000-0000000000a1', mt07, 2021),
    'an account cannot ask about another';
end $$;

-- B's saved search for any model finds only B's listings.
insert into public.saved_searches (name) values ('Tudo');
reset role;
do $$
begin
  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches m
          join public.listings l on l.id = m.listing_id) = array['mt07-2026'],
    'the search follows its owner''s models and years';
end $$;

-- The anonymous session sees everything collected, from the collected year.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  assert (select array_agg(source_listing_id order by source_listing_id)
          from public.listings l where public.in_my_models(l))
         = array['cbr-2025', 'mt07-2021', 'mt07-2026'], 'anonymous: every collected model';
end $$;

-- No session yet (the app's first visit asks for the first listings while
-- it signs in): the same as an anonymous session.
set local role anon;
set local test.uid = '';
set local test.jwt = '';
do $$
begin
  assert (select array_agg(source_listing_id order by source_listing_id)
          from public.listings l where public.in_my_models(l))
         = array['cbr-2025', 'mt07-2021', 'mt07-2026'], 'no session: every collected model';
  assert (select array_agg(m.slug order by m.slug) from public.motorcycles m
          where public.tracked_by_me(m))
         = array['honda-cbr650r', 'yamaha-mt-07'], 'no session: the collected models';
end $$;
set local role authenticated;

-- A stops following the CBR650R: nobody does, so it is no longer collected
-- and its listings lose the model. B stopping the MT-07 leaves it to A.
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
select public.set_model_tracked((select id from public.motorcycles where slug = 'honda-cbr650r'), false);
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
select public.set_model_tracked((select id from public.motorcycles where slug = 'yamaha-mt-07'), false);
reset role;
do $$
begin
  assert (select not is_active from public.motorcycles where slug = 'honda-cbr650r'),
    'nobody follows it: not collected';
  assert (select count(*) from public.listings
          where source_listing_id like 'cbr-%' and motorcycle_id is null) = 2,
    'its listings lose the model';
  assert (select is_active and min_year = 2020 from public.motorcycles where slug = 'yamaha-mt-07'),
    'A still follows the MT-07';
  assert (select tracked and min_year = 2026 from public.user_models
          where user_id = '00000000-0000-0000-0000-0000000000b1') is false,
    'B''s year is kept for later';
end $$;

-- A model added by an account is followed by that account only.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
select public.add_catalog_model('Honda', 'Forza 350', 2022,
  'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/');
reset role;
do $$
begin
  assert (select array_agg(user_id) from public.user_models u
          join public.motorcycles m on m.id = u.motorcycle_id
          where m.model = 'Forza 350' and u.tracked and u.min_year = 2022)
         = array['00000000-0000-0000-0000-0000000000a1'::uuid], 'added: followed by A';
end $$;
