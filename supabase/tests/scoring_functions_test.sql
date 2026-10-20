-- The pure scoring functions, with literal values: price, year and mileage
-- scores, the deal-score combiner, the age/mileage adjustment, duplicate
-- similarity and the risk signals.
do $$
declare
  this_year int := extract(year from current_date)::int;
  r record;
begin
  -- price_score: 50 at the market price, 5 points per percent, 0..100.
  assert public.price_score(10000, 10000) = 50, 'at the market price';
  assert public.price_score(9500, 10000) = 75, '5 % below';
  assert public.price_score(10500, 10000) = 25, '5 % above';
  assert public.price_score(9000, 10000) = 100, '10 % below is the top';
  assert public.price_score(5000, 10000) = 100, 'clamped at 100';
  assert public.price_score(12000, 10000) = 0, 'clamped at 0';
  assert public.price_score(null, 10000) is null, 'no price';
  assert public.price_score(9000, null) is null, 'no market price';
  assert public.price_score(9000, 0) is null, 'market price 0';

  -- year_score: 10 points a year below the reference.
  assert public.year_score(2026, 2026) = 100, 'this year';
  assert public.year_score(2020, 2026) = 40, 'six years old';
  assert public.year_score(2027, 2026) = 100, 'next year clamped';
  assert public.year_score(2010, 2026) = 0, 'old clamped';
  assert public.year_score(null, 2026) is null, 'no year';
  assert public.year_score(this_year) = 100, 'the reference defaults to this year';

  -- mileage_score: linear from 100 at 0 km to 0 at 20 000 km.
  assert public.mileage_score(0) = 100, 'new';
  assert public.mileage_score(5000) = 75, '5 000 km';
  assert public.mileage_score(25000) = 0, 'clamped at 0';
  assert public.mileage_score(-1) is null, 'negative mileage';
  assert public.mileage_score(null) is null, 'no mileage';
  assert public.mileage_score(1000, 0) is null, 'no scale';

  -- combine_deal_score: weighted average of the slices with data.
  select * into r from public.combine_deal_score(80, 50, 100, 20);
  -- price 80*35, year/mileage (0.7*50 + 0.3*100 = 65)*20, risk (100-20)*10
  assert r.deal_score = 75, format('three slices, got %s', r.deal_score);
  assert (r.breakdown ->> 'slices_used')::int = 3, 'three slices used';
  assert (r.breakdown -> 'scores' ->> 'year_mileage')::numeric = 65, 'year/mileage blend';
  assert (r.breakdown -> 'scores' ->> 'risk')::numeric = 80, 'risk is inverted';
  assert not (r.breakdown -> 'scores') ? 'equipment', 'no equipment, no slice';

  select * into r from public.combine_deal_score(80, 50, 100, 20, 90);
  assert r.deal_score = 78, format('with equipment, got %s', r.deal_score);
  assert (r.breakdown -> 'weights' ->> 'equipment')::numeric = 15, 'equipment weight';

  select * into r from public.combine_deal_score(null, 40, null, null);
  assert r.deal_score = 40, 'mileage alone is the year/mileage slice';
  assert (r.breakdown ->> 'slices_used')::int = 1, 'one slice used';

  select * into r from public.combine_deal_score(null, null, null, null);
  assert r.deal_score is null, 'nothing known, no score';
  assert r.breakdown -> 'scores' = '{}'::jsonb, 'empty breakdown';

  -- age_mileage_factor: 4 %/year, 0.2 %/1000 km, kept within 0.6..1.6.
  assert public.age_mileage_factor(0, 0) = 1, 'same bike';
  assert public.age_mileage_factor(null, null) = 1, 'unknown differences';
  assert round(public.age_mileage_factor(1, 0), 4) = 1.0408, 'one year newer';
  assert round(public.age_mileage_factor(0, 10000), 4) = 0.9802, '10 000 km more';
  assert round(public.age_mileage_factor(0, 10000, 0.04, 0.01), 4) = 0.9048, 'own mileage rate';
  assert public.age_mileage_factor(-100, 0) = 0.6, 'floor';
  assert public.age_mileage_factor(100, 0) = 1.6, 'ceiling';

  -- duplicate_similarity: mileage 40, price 20, place 20, text 30, dealer 10.
  assert public.duplicate_similarity(
    12000, 12000, 10000, 10000, 'Porto', ' porto ',
    'Yamaha MT-07 impecável, revisões na marca, pneus novos, sempre em garagem.',
    'Yamaha MT-07 impecável, revisões na marca, pneus novos, sempre em garagem.',
    'Moto X', 'moto x') = 120, 'everything the same';
  assert public.duplicate_similarity(300, 300, null, null, null, null, null, null, null, null) = 10,
    'the same low mileage counts little';
  assert public.duplicate_similarity(12000, 12080, null, null, null, null, null, null, null, null) = 20,
    'mileage within 100 km';
  assert public.duplicate_similarity(null, null, 10000, 9500, null, null, null, null, null, null) = 10,
    'price within 10 %';
  assert public.duplicate_similarity(null, null, 10000, 8000, null, null, null, null, null, null) = 0,
    'price 20 % apart';
  assert public.duplicate_similarity(null, null, null, null, ' ', ' ', 'curta', 'curta', '', '') = 0,
    'blank places, short texts and blank dealers count nothing';

  -- risk_assessment
  select * into r from public.risk_assessment(7000, 10000, this_year - 1, 5000,
    'Mota impecável, sem sinistros, revisões feitas na marca.', 'Lisboa');
  assert r.risk_score = 45 and r.reasons = array['price_far_below_market'],
    format('30 %% below the market, got %s %s', r.risk_score, r.reasons);

  select * into r from public.risk_assessment(8000, 10000, this_year - 1, 5000,
    'Teve um acidente ligeiro.', 'Lisboa');
  assert r.risk_score = 55 and r.reasons = array['possible_accident', 'price_below_market'],
    format('20 %% below and an accident, got %s %s', r.risk_score, r.reasons);

  select * into r from public.risk_assessment(null, null, null, null, null, null);
  assert r.risk_score = 30 and r.reasons = array['no_mileage', 'no_year', 'no_location'],
    format('nothing known, got %s %s', r.risk_score, r.reasons);

  select * into r from public.risk_assessment(null, null, this_year - 5, 50, null, 'Porto');
  assert r.reasons = array['suspicious_mileage'], 'a placeholder mileage on an old bike';
  select * into r from public.risk_assessment(null, null, this_year - 1, 50, null, 'Porto');
  assert r.reasons = '{}', 'a low mileage on a recent bike is fine';
  select * into r from public.risk_assessment(null, null, this_year, 30000, null, 'Porto');
  assert r.reasons = array['suspicious_mileage'], 'over 25 000 km a year';

  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, 'Vendo', 'Porto', true, true);
  assert r.reasons = array['thin_description'], 'a private seller''s thin description';
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, 'Vendo', 'Porto', true, false);
  assert r.reasons = '{}', 'a dealer''s short text is not a signal';
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, 'Vendo', 'Porto', false, true);
  assert r.reasons = '{}', 'nor one whose page was not read';

  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, 3, false, 'imported');
  assert r.risk_score = 35 and r.reasons = array['many_owners', 'imported', 'no_service_book'],
    format('owners, no book, imported, got %s %s', r.risk_score, r.reasons);

  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, 1, true, 'national', current_date + 30);
  assert r.risk_score = 0 and r.reasons = array['first_owner', 'service_book', 'under_warranty'],
    format('reassuring signals floor at 0, got %s %s', r.risk_score, r.reasons);

  select * into r from public.risk_assessment(5000, 10000, this_year - 1, null, 'Bateu.', '',
    false, false, 4);
  assert r.risk_score = 100, format('clamped at 100, got %s', r.risk_score);

  -- Relisted: once (5), twice or on sale for over 90 days (10).
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, null, null, null, null, 1, now() - interval '40 days');
  assert r.risk_score = 5 and r.reasons = array['relisted'],
    format('relisted once, got %s %s', r.risk_score, r.reasons);
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, null, null, null, null, 1, now() - interval '91 days');
  assert r.risk_score = 10 and r.reasons = array['relisted_often'],
    format('relisted, on sale for 91 days, got %s %s', r.risk_score, r.reasons);
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, null, null, null, null, 2, now() - interval '40 days');
  assert r.reasons = array['relisted_often'], 'relisted twice';
  select * into r from public.risk_assessment(null, null, this_year - 1, 5000, null, 'Porto',
    false, false, null, null, null, null, 0, now() - interval '200 days');
  assert r.reasons = '{}', 'a long time on sale alone is not a relist';
end $$;

-- text_contradictions: only clear differences between the text and the fields.
do $$
declare
  r record;
begin
  assert public.text_contradictions('Mota de 2021, matrícula de 2018.', 2021, null, null, null)
         = array['text_year_mismatch'], 'registration year 3 years off';
  assert public.text_contradictions('Ano 2020, matriculada em 2021.', 2021, null, null, null)
         = '{}', 'one year off (built and registered) is fine';
  assert public.text_contradictions('Revisão feita em 2018.', 2021, null, null, null)
         = '{}', 'other years in the text are not the bike''s';

  assert public.text_contradictions('Tem 30 mil km, sempre na garagem.', 2021, 12000, null, null)
         = array['text_mileage_mismatch'], '30 mil km in the text, 12 000 in the field';
  assert public.text_contradictions('Com 30.000 km reais.', 2021, 12000, null, null)
         = array['text_mileage_mismatch'], 'dotted thousands';
  assert public.text_contradictions('Pneus com 2000 km, revisão aos 40 000 km.', 2021, 12000, null, null)
         = '{}', 'fewer km in the text are the tyres; "aos" is a service';
  assert public.text_contradictions('Tem 13 000 km.', 2021, 12000, null, null)
         = '{}', 'close enough';

  assert public.text_contradictions('Mota importada de Espanha.', null, null, 'national', null)
         = array['text_origin_mismatch'], 'imported in the text, national in the ad';
  assert public.text_contradictions('Nacional, não é importada.', null, null, 'national', null)
         = '{}', 'a denial does not count';
  assert public.text_contradictions('Mota importada.', null, null, 'imported', null)
         = '{}', 'the ad already says so';

  assert public.text_contradictions('Vendo sem livro de revisões.', null, null, null, true)
         = array['text_service_book_mismatch'], 'no book in the text, book in the ad';
  assert public.text_contradictions('Vendo sem livro.', null, null, null, false)
         = '{}', 'the ad already says so';

  assert public.text_contradictions(null, null, null, null, null) = '{}', 'nothing to compare';

  select * into r from public.risk_assessment(null, null, 2021, 12000,
    'Tem 30 mil km, matrícula de 2018.', 'Porto');
  assert r.risk_score = 20
         and r.reasons = array['text_mileage_mismatch', 'text_year_mismatch'],
    format('each contradiction is 10 points, got %s %s', r.risk_score, r.reasons);
end $$;
