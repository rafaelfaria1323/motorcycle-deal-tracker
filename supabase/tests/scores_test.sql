-- Scoring: the equipment slice and the extras it reads, and the Deal
-- Score ranking a cheaper bike above a dearer one of the same year and km.
do $$
begin
  assert public.equipment_score(array['quickshifter']) = 70, 'one extra: 70';
  assert public.equipment_score(array['quickshifter', 'exhaust']) = 80, '+10 for each more';
  assert public.equipment_score(array['a', 'b', 'c', 'd', 'e', 'f']) = 100, 'at most 100';
  assert public.equipment_score(array[]::text[]) is null, 'none: the slice is skipped';
  assert public.listing_extras('Akrapovic', 'Tem quickshifter, sem punhos aquecidos')
           = array['exhaust', 'quickshifter'], '"sem ..." is not an extra';
end $$;

-- The words sellers use (Rafael's examples first).
do $$
declare
  cases text[][] := array[
    ['Suporte curto de matrícula e cogumelos', 'protection,tail_tidy'],
    ['Bolha escurecida, manetes ajustáveis', 'levers,screen'],
    ['eliminador de guarda-lamas', 'tail_tidy'],
    ['porta matrícula desportivo', 'tail_tidy'],
    ['bolha fumada da Puig', 'screen'],
    ['para-brisas alto', 'screen'],
    ['espelhos de ponta de guiador', 'mirrors'],
    ['suporte para telemóvel e tomada USB', 'phone_mount'],
    ['Mapit GPS', 'alarm'],
    ['amortecedor de direção', 'steering_damper'],
    ['descanso central', 'centre_stand'],
    ['cruise control', 'cruise_control'],
    ['amortecedor Öhlins', 'suspension'],
    ['piscas em LED', 'led_indicators'],
    ['farol LED de origem', ''],
    ['mala de depósito', 'luggage'],
    ['proteção de radiador e barras de proteção', 'protection'],
    ['crash bars', 'protection'],
    ['pneus Michelin novos', 'new_tyres'],
    ['pneus a 50%', ''],
    ['escape GPR', 'exhaust'],
    ['ponteira de escape', 'exhaust'],
    ['ponteiras de guiador', ''],
    ['manoplas aquecidas', 'heated_grips'],
    ['up/down shifter', 'quickshifter'],
    ['sem cogumelos', '']
  ];
  i int;
  got text;
begin
  for i in 1 .. array_length(cases, 1) loop
    got := array_to_string(public.listing_extras(null, cases[i][1]), ',');
    assert got = cases[i][2], format('%s: expected "%s", got "%s"', cases[i][1], cases[i][2], got);
  end loop;
end $$;

-- Mileage against the bike's age: 5 000 km a year is normal.
do $$
begin
  assert public.expected_mileage(2026, 5000, 2026) = 5000, 'a bike of this year: one year''s';
  assert public.expected_mileage(2025, 5000, 2026) = 7500, 'last year''s: 1.5 years';
  assert public.expected_mileage(2016, 5000, 2026) = 52500;
  assert public.mileage_use_score(1000, 2026, 5000, 2026) = 100, 'under half the normal: 100';
  assert public.mileage_use_score(20000, 2022, 5000, 2026) = 81, 'a little under the normal 22 500 km';
  assert public.mileage_use_score(22500, 2022, 5000, 2026) = 75, 'exactly the normal: 75';
  assert public.mileage_use_score(17500, 2025, 5000, 2026) = 8, '17 500 km on a 1.5-year-old bike';
  assert public.mileage_use_score(25000, 2025, 5000, 2026) = 0, 'from 2.5 times the normal: 0';
  assert public.mileage_use_score(30000, 2016, 5000, 2026) = 96, '30 000 km on a 10-year-old bike is little';
  assert public.mileage_use_score(16000, 2024, 5000, 2026) = 61, '1.28 times the normal';
  assert public.mileage_use_score(5000, null, 5000, 2026) = public.mileage_score(5000), 'no year: the flat score';
  assert public.mileage_use_score(null, 2020, 5000, 2026) is null;
end $$;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type)
select 'olx', 's' || i, 'https://x/s' || i, m.id, m.brand, m.model, 2022, 12000,
       6000 + i * 250, 'Lisboa', 'Mota estimada número ' || i || ', revisões feitas.', 'dealer'
from public.motorcycles m, generate_series(0, 8) i
where m.slug = 'honda-cb650r';

do $$
declare
  cheapest smallint;
  dearest smallint;
begin
  perform public.recalculate_deal_scores();
  select deal_score into cheapest from public.listings where source_listing_id = 's0';
  select deal_score into dearest from public.listings where source_listing_id = 's8';
  assert cheapest is not null and dearest is not null, 'both scored';
  assert cheapest > dearest, format('cheapest %s should beat dearest %s', cheapest, dearest);
  assert (select score_breakdown is not null from public.listings where source_listing_id = 's0'),
    'the explanation is stored';
end $$;
