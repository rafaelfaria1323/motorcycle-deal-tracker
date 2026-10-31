-- No phone numbers stored (20261031120000_no_phone_numbers.sql).
do $$
declare
  c record;
  l public.listings%rowtype;
  m uuid;
begin
  for c in
    select * from (values
      ('Contacto 912 345 678', 'Contacto'),
      ('Ligue 912345678 ou 21 234 5678.', 'Ligue ou .'),
      ('Tlm: +351 936 123 456', 'Tlm:'),
      ('Tlm: +351936123456', 'Tlm:'),
      ('Tel. 00351 253.123.456', 'Tel.'),
      ('Whatsapp 961-23-45-67, só chamadas', 'Whatsapp , só chamadas'),
      (E'Mota impecável.\nContacto: 912 345 678\nSem trocas', E'Mota impecável.\nContacto:\nSem trocas'),
      ('912345678', null),
      -- Not phone numbers: kept as they are.
      ('Ano 2019 com 20.000 km, 9.500 €', 'Ano 2019 com 20.000 km, 9.500 €'),
      ('2019 20000 km', '2019 20000 km'),
      ('Quilometragem: 212345', 'Quilometragem: 212345'),
      ('Referência 2123456789', 'Referência 2123456789'),
      ('Código postal 4000-123 Porto', 'Código postal 4000-123 Porto'),
      ('Número 812 345 678', 'Número 812 345 678'),
      ('Matrícula AA-12-BB', 'Matrícula AA-12-BB'),
      (null, null)
    ) t(input, expected)
  loop
    assert public.without_phone_numbers(c.input) is not distinct from c.expected,
      format('%L: expected %L, got %L', c.input, c.expected,
             public.without_phone_numbers(c.input));
  end loop;

  -- Stored listings lose them on the way in, whatever the column.
  select id into m from public.motorcycles order by id limit 1;
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, variant, price, seller_type,
                               seller_name, description)
  values ('olx', 'olx.pt/phone-test', 'https://www.olx.pt/d/phone-test', m,
          'Yamaha', 'MT-07', 'MT-07 912 345 678', 6000, 'dealer',
          'Motos Lda 253 123 456', E'Com 12.000 km.\nLigue 936 123 456')
  returning * into l;
  assert l.description = 'Com 12.000 km.' || E'\n' || 'Ligue',
    format('description %L', l.description);
  assert l.variant = 'MT-07', format('variant %L', l.variant);
  assert l.seller_name = 'Motos Lda', format('seller %L', l.seller_name);
  assert l.mileage = 12000 or l.mileage is null, 'the mileage is still read';

  update public.listings
  set description = 'Nova descrição, 961 234 567'
  where id = l.id
  returning * into l;
  assert l.description = 'Nova descrição,', format('updated %L', l.description);
end;
$$;
