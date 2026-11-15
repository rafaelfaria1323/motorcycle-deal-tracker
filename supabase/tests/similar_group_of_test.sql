-- B.4 (20261115220000_similar_group_of.sql): a model added later joins
-- its platform group by its name.
do $$
declare
  xsr uuid;
  mt uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
begin
  assert public.similar_group_of('YAMAHA', 'XSR 700') = 'yamaha-cp2', 'by letters and digits';
  assert public.similar_group_of('Honda', 'CB 500 Hornet') = 'honda-500-twin', 'another platform';
  assert public.similar_group_of('Honda', 'XSR 700') is null, 'the brand counts';
  assert public.similar_group_of('Yamaha', 'Tenere 700') is null, 'not every model has a group';

  insert into public.motorcycles (brand, model, slug, min_year)
  values ('Yamaha', 'XSR 700', 'yamaha-xsr-700-test', 2020)
  returning id into xsr;
  assert (select similar_group from public.motorcycles where id = xsr) = 'yamaha-cp2',
    'a new model joins its group';
  assert xsr = any(public.similar_motorcycle_ids(mt)), 'and the MT-07 borrows from it';

  insert into public.motorcycles (brand, model, slug, min_year, similar_group)
  values ('Yamaha', 'XSR 700 XTribute', 'yamaha-xsr-700-xt-test', 2020, 'custom');
  assert (select similar_group from public.motorcycles where slug = 'yamaha-xsr-700-xt-test') = 'custom',
    'a group given is kept';
  insert into public.motorcycles (brand, model, slug, min_year)
  values ('Yamaha', 'Tenere 700', 'yamaha-tenere-700-test', 2020);
  assert (select similar_group from public.motorcycles where slug = 'yamaha-tenere-700-test') is null,
    'no group: none';
end $$;
