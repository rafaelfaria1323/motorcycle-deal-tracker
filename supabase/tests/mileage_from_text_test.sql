-- Mileage read from the description when the ad's field is empty
-- (20261024200000_mileage_from_text.sql).
do $$
declare
  c record;
begin
  for c in
    select * from (values
      ('Mota com 12.000 km, revisões feitas.', 12000),
      ('Vendo Yamaha MT-07 de 2019. 15 mil kms. Pneus novos com 2000 km.', 15000),
      ('Quilometragem: 8500', 8500),
      ('Kms: 12.345. Revisão feita aos 10.000 km', 12345),
      ('Única dona, 9 800 km, sempre na garagem', 9800),
      ('Tem 12000km. Fiz uma viagem de 300 km a Espanha.', 12000),
      ('12,5 mil km reais', 12500),
      ('Pneus com 2000 km. Revisão feita aos 10000 km.', null),
      ('Velocidade máxima 210 km/h', null),
      ('Faço 300 km por mês', null),
      ('Garantia de 2 anos ou 20000 km', null),
      ('Revisões a cada 10 000 km', null),
      ('Vendo por 12000 km ou 13000 km', null),
      ('Mota impecável', null),
      (null, null)
    ) t(description, km)
  loop
    assert public.mileage_in_text(c.description) is not distinct from c.km,
      format('%L: expected %s, got %s', c.description, c.km,
             public.mileage_in_text(c.description));
  end loop;
end $$;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, mileage, description)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000, v.km, v.description
from public.motorcycles m,
     (values ('text', null::integer, 'Mota com 12.000 km.'),
             ('field', 5000, 'Mota com 12.000 km.'),
             ('later', null, null)) v(sid, km, description)
where m.slug = 'yamaha-mt-07';

do $$
begin
  assert (select mileage = 12000 and mileage_from_text
          from public.listings where source_listing_id = 'text'),
    'an empty field is filled from the text';
  assert (select mileage = 5000 and not mileage_from_text
          from public.listings where source_listing_id = 'field'),
    'the ad''s own field wins';
  assert (select mileage is null and not mileage_from_text
          from public.listings where source_listing_id = 'later'),
    'no text, no mileage';

  -- Standvirtual's listing page brings the description later.
  perform public.apply_listing_details('olx',
    '[{"source_listing_id": "later", "description": "Apenas 7 mil km."}]');
  assert (select mileage = 7000 and mileage_from_text
          from public.listings where source_listing_id = 'later'),
    'filled when the description arrives';

  update public.listings set description = 'Mota impecável.'
  where source_listing_id in ('text', 'field');
  assert (select mileage is null and not mileage_from_text
          from public.listings where source_listing_id = 'text'),
    'a mileage from the text follows the text';
  assert (select mileage = 5000 from public.listings where source_listing_id = 'field'),
    'the field''s mileage stays';
end $$;
