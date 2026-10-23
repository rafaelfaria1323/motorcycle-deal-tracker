-- A saved search can ask for several models (motorcycle_ids, empty: any);
-- an older app build writing the single motorcycle_id replaces the list.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1');
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year from auth.users u cross join public.motorcycles m
where m.is_active;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', m.slug, 'https://x/' || m.slug, m.id, m.brand, m.model, 7000
from public.motorcycles m
where m.slug in ('honda-cb650r', 'honda-cbr650r', 'yamaha-mt-07');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
insert into public.saved_searches (name, motorcycle_ids)
select 'Duas Honda', array_agg(id) from public.motorcycles
where slug in ('honda-cb650r', 'honda-cbr650r');
insert into public.saved_searches (name) values ('Todas');
-- An older build sends one model.
insert into public.saved_searches (name, motorcycle_id)
select 'Antiga', id from public.motorcycles where slug = 'yamaha-mt-07';

do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Duas Honda') = array['honda-cb650r', 'honda-cbr650r'],
         'only the two models asked for';
  assert (select count(*)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Todas' and l.source_listing_id in
            ('honda-cb650r', 'honda-cbr650r', 'yamaha-mt-07')) = 3,
         'an empty list is any model';
  assert (select motorcycle_ids = array[mt07] and motorcycle_id is null
          from public.saved_searches where name = 'Antiga'),
         'the single model becomes the list';
  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Antiga') = array['yamaha-mt-07'],
         'and matches as before';

  -- An older build clearing the model: any model again.
  update public.saved_searches set motorcycle_id = null where name = 'Antiga';
  assert (select cardinality(motorcycle_ids) = 0
          from public.saved_searches where name = 'Antiga'),
         'cleared single model clears the list';

  -- The new app's edits leave the list alone.
  update public.saved_searches set motorcycle_ids = array[mt07], name = 'Nova'
  where name = 'Antiga';
  update public.saved_searches set max_price = 8000 where name = 'Nova';
  assert (select motorcycle_ids = array[mt07]
          from public.saved_searches where name = 'Nova'),
         'other edits keep the list';
end;
$$;
