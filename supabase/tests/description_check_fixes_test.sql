-- The phrases the first description check (N.55) found the rules missing
-- or misreading (20261111130000_description_check_fixes.sql).
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('Ano 2025 Km 7.500', 7500),
      ('Km 7.500', 7500),
      ('25,673 km', 25673),
      ('Kms 25,673', 25673),
      ('A monta conta com 3550 km', 3550),
      ('10mil/km', 10000),
      ('8.651kms', 8651),
      ('12.000 km 2019', 12000),
      ('1,5 km', null),
      ('km 2019 nova', null),
      ('revisão dos 52000km', null),
      ('com 15.000 km montei escape', null)
    ) v(t, km)
  loop
    assert public.mileage_in_text(r.t) is not distinct from r.km,
      format('mileage_in_text(%L) = %s, expected %s',
             r.t, public.mileage_in_text(r.t), r.km);
  end loop;

  for r in
    select * from (values
      ('linha de escape completa', 'exhaust'),
      ('Escape Arkapovick', 'exhaust'),
      ('mala Shad traseira', 'luggage'),
      ('top box givi', 'luggage'),
      ('protetores laterais', 'protection'),
      ('pneus foram trocados', 'new_tyres'),
      ('vidro Givi alto', 'screen'),
      ('defletor frontal', 'screen'),
      ('espelhos de punho', 'mirrors'),
      ('segue todo o material original', 'original_parts'),
      ('vem com o vidro original', 'original_parts')
    ) v(t, code)
  loop
    assert r.code = any(public.listing_extras(null, r.t)),
      format('listing_extras(%L) = %s, expected %s',
             r.t, public.listing_extras(null, r.t), r.code);
  end loop;

  assert public.listing_extras(null,
    'o vidro está riscado, a mala do carro, vai com seguro') = '{}';

  assert public.mentions_accident('Danos de queda na carenagem');
  assert not public.mentions_accident('Sem danos de queda');
  assert public.needs_repair(
    'Necessita de travão traseiro e dianteiro assim como disco');
  assert not public.needs_repair('Travões e discos novos');
end
$$;

