-- F.2: a price under 300 € is a placeholder. The computed field
-- asking_price leaves it out (the price sorts put it last), and a maximum
-- price, in Ofertas or a saved search, doesn't match it.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f2');
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year from auth.users u cross join public.motorcycles m
where m.is_active and u.id = '00000000-0000-0000-0000-0000000000f2';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.price
from public.motorcycles m,
     (values ('one-euro', 1::numeric), ('just-under', 299.99), ('floor', 300),
             ('real', 6500), ('none', null)) v(sid, price)
where m.slug = 'yamaha-mt-07';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000f2';
insert into public.saved_searches (name, max_price) values ('Até 8 000', 8000);

do $$
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.listings l
          where l.source_listing_id in ('one-euro', 'just-under', 'floor', 'real', 'none')
            and public.asking_price(l) is null)
         = array['just-under', 'none', 'one-euro'],
    'placeholders and missing prices have no asking price';
  assert (select public.asking_price(l) from public.listings l
          where l.source_listing_id = 'floor') = 300, '300 € is a real price';

  -- As PostgREST orders "Mais barato primeiro": real prices first.
  assert (select array_agg(source_listing_id order by public.asking_price(l) nulls last,
                                                      source_listing_id)
          from public.listings l
          where l.source_listing_id in ('one-euro', 'floor', 'real'))
         = array['floor', 'real', 'one-euro'],
    'a placeholder sorts after every real price';

  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'Até 8 000') = array['floor', 'real'],
    'a maximum price matches only real prices';
end $$;
reset role;

-- Without a maximum price, a placeholder still matches.
do $$
begin
  assert public.listing_matches_search(
    null, 2020, 1, 1000, null, 'private', null, null, null, null, null, null),
    'no maximum price: any price';
  assert not public.listing_matches_search(
    null, 2020, 1, 1000, null, 'private', null, null, 8000, null, null, null),
    'a placeholder is not under a maximum';
end $$;
