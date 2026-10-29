-- Scoring: the extras read from the ads, and the Deal
-- Score ranking a cheaper bike above a dearer one of the same year and km.
do $$
begin
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
    ['sem cogumelos', ''],
    -- An ad Rafael found (OLX, 2024, 6 000 km).
    [E'tem todas as partes de origem\nVai com escape after market\nSuporte matricula curto\nProteções motor\nManteres curtas\nquickshift original\nSuporte maos pendura',
     'exhaust,levers,original_parts,passenger_grips,protection,quickshifter,tail_tidy'],
    ['escape original incluído', 'original_parts'],
    ['entrego as peças originais', 'original_parts'],
    ['pneus originais, mantém tudo de origem', ''],
    ['pegas para o pendura', 'passenger_grips']
  ];
  i int;
  got text;
begin
  for i in 1 .. array_length(cases, 1) loop
    got := array_to_string(public.listing_extras(null, cases[i][1]), ',');
    assert got = cases[i][2], format('%s: expected "%s", got "%s"', cases[i][1], cases[i][2], got);
  end loop;
end $$;

-- Mileage against the bike's age: 5 000 km a year is normal. The reference
-- is a decimal year: 2027 is 1 January 2027 (the end of 2026).
do $$
begin
  assert public.expected_mileage(2026, 5000, 2027) = 5000, 'a bike of this year: one year''s';
  assert public.expected_mileage(2025, 5000, 2027) = 7500, 'last year''s: 1.5 years';
  assert public.expected_mileage(2016, 5000, 2027) = 52500;
  assert public.mileage_use_score(1000, 2026, 5000, 2027) = 100, 'under half the normal: 100';
  assert public.mileage_use_score(20000, 2022, 5000, 2027) = 81, 'a little under the normal 22 500 km';
  assert public.mileage_use_score(22500, 2022, 5000, 2027) = 75, 'exactly the normal: 75';
  assert public.mileage_use_score(17500, 2025, 5000, 2027) = 8, '17 500 km on a 1.5-year-old bike';
  assert public.mileage_use_score(25000, 2025, 5000, 2027) = 0, 'from 2.5 times the normal: 0';
  assert public.mileage_use_score(30000, 2016, 5000, 2027) = 96, '30 000 km on a 10-year-old bike is little';
  assert public.mileage_use_score(16000, 2024, 5000, 2027) = 61, '1.28 times the normal';
  assert public.mileage_use_score(5000, null, 5000, 2027) = public.mileage_score(5000), 'no year: the flat score';
  assert public.mileage_use_score(null, 2020, 5000, 2027) is null;
  assert public.decimal_year('2026-07-02') between 2026.49 and 2026.51, 'mid-year';
  assert abs(public.expected_mileage(2024, 5000, public.decimal_year('2026-01-01'))
             - public.expected_mileage(2024, 5000, public.decimal_year('2025-12-31'))) < 20,
    'no jump on 1 January';
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

-- Comparables: near the listing's year when there are 5 of them; no token
-- prices; hidden mileage counts as 50.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type)
select 'olx', 'r' || i, 'https://x/r' || i, m.id, m.brand, m.model,
       case when i = 0 then 2015 when i <= 5 then 2013 + i else 2023 + i % 3 end,
       case when i = 16 then null else 20000 end,
       case when i = 15 then 200 else 9000 end,
       'Lisboa', 'Mota de teste ' || i, 'dealer'
from public.motorcycles m, generate_series(0, 16) i
where m.slug = 'yamaha-r1';

do $$
declare
  n bigint;
begin
  select f.comparable_count into n
  from public.listing_fair_prices f
  join public.listings l on l.id = f.listing_id
  where l.source_listing_id = 'r0';
  assert n = 5, format('only the 5 bikes within 3 years, got %s', n);

  assert not exists (select 1 from public.listing_fair_prices f
                     join public.listings l on l.id = f.listing_id
                     where l.source_listing_id = 'r15'),
    'a 200 € ad gets no estimate';

  perform public.recalculate_deal_scores();
  assert (select (score_breakdown -> 'scores' ->> 'year_mileage')::numeric
          from public.listings where source_listing_id = 'r16')
         = round(0.7 * 50 + 0.3 * public.age_score(2024), 1),
    'hidden mileage counts as 50';
end $$;

-- Only the extras worth money add points (Rafael, 2026-10-22: five small
-- extras lifted an older bike above a newer one with fewer km).
update public.listings
set description = 'Com quickshifter, piscas LED, tomada USB, manetes ajustáveis e cogumelos.'
where source_listing_id = 's4';

do $$
declare
  b jsonb;
begin
  perform public.recalculate_deal_scores();
  select score_breakdown into b from public.listings where source_listing_id = 's4';
  assert jsonb_array_length(b -> 'extras') = 5, format('every extra listed: %s', b -> 'extras');
  assert b -> 'valued_extras' = '["quickshifter"]'::jsonb,
    format('only the quickshifter is valued: %s', b -> 'valued_extras');
  assert (b ->> 'equipment_bonus')::int = 1, format('one point: %s', b ->> 'equipment_bonus');
end $$;

-- An A2 version, read from the ad's variant, is a risk reason (Rafael,
-- 2026-10-22: full power from the factory beats an A2 bike).
update public.listings set variant = '35kW' where source_listing_id = 's4';

do $$
declare
  b jsonb;
begin
  perform public.recalculate_deal_scores();
  select score_breakdown into b from public.listings where source_listing_id = 's4';
  assert b -> 'risk_reasons' ? 'a2_limited', format('held back: %s', b -> 'risk_reasons');
end $$;
