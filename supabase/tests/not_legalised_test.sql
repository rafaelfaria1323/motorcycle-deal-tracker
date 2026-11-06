-- Bikes not yet legalised in Portugal (N.52).

do $$
begin
  -- Still to be legalised, or a foreign registration not said to be done.
  assert public.legalisation_status(null,
    'Mota matriculada em Inglaterra. Falta apenas trocar o pneu e proceder à legalização e matrícula em Portugal.')
    = 'not_legalised_outside_eu', 'the CBR650R that started it';
  assert public.legalisation_status('CBR650R matrícula inglesa', null)
    = 'not_legalised_outside_eu', 'English plate in the title';
  assert public.legalisation_status(null, 'Matrícula espanhola, por legalizar.')
    = 'not_legalised', 'Spanish, to legalise';
  assert public.legalisation_status(null, 'Com matrícula francesa.')
    = 'not_legalised', 'French plate';
  assert public.legalisation_status(null, 'Precisa de ser legalizada, documentos em ordem.')
    = 'not_legalised', 'needs legalising';
  assert public.legalisation_status(null, 'Não está legalizada em Portugal.')
    = 'not_legalised', 'not legalised';
  assert public.legalisation_status(null, 'Legalização a cargo do comprador.')
    = 'not_legalised', 'buyer legalises';
  assert public.legalisation_status(null, 'Matrícula suíça, ainda não legalizada.')
    = 'not_legalised_outside_eu', 'Swiss';
  -- Legalised already, or nothing about it.
  assert public.legalisation_status(null, 'Importada da Alemanha, já legalizada.') is null,
    'legalised';
  assert public.legalisation_status(null, 'Veio com matrícula espanhola, legalizada em Portugal em 2024.') is null,
    'foreign plate, legalised';
  assert public.legalisation_status(null, 'Matrícula portuguesa, livro de revisões.') is null,
    'Portuguese plate';
  assert public.legalisation_status(null, 'Não precisa de legalizar nada, tudo em dia.') is null,
    'needs nothing';
  assert public.legalisation_status(null, 'Revisões feitas, manual em inglês.') is null,
    'English manual';
  assert public.legalisation_status(null, null) is null, 'no text';

  assert public.description_signals(null, 'Matrícula espanhola, por legalizar.')
    @> array['not_legalised'], 'in the text signals';

  -- The costs: ISV + 225 € of fees; outside the EU 30 % of the price; a
  -- nearly new bike from the EU 23 %.
  assert public.legalisation_cost('{}', 649, 9000, 2020, 30000) = 0, 'nothing to legalise';
  assert public.legalisation_cost(array['not_legalised'], 649, 9000, 2020, 30000)
    = 184.45 + 225, 'EU, used';
  assert public.legalisation_cost(array['not_legalised'], 649, 9000,
    extract(year from current_date)::int, 3000) = 184.45 + 225 + 9000 * 0.23,
    'EU, new for VAT';
  assert public.legalisation_cost(array['not_legalised_outside_eu'], 649, 9000, 2020, 30000)
    = 184.45 + 225 + 2700, 'outside the EU';
  assert public.legalisation_cost(array['not_legalised'], null, 9000, 2020, 30000)
    = 245.14 + 225, 'unknown engine: the top band';
  assert public.motorcycle_isv(125) = 73.78 and public.motorcycle_isv(119) = 0,
    'ISV bands';

  -- Risk: in place of imported.
  assert (select r.reasons from public.risk_from_signals(
            9000, 9000, 2026, 6000, 'x', 'Lisboa', true, false, null, null,
            'imported', null, 0, null, array['not_legalised_outside_eu']) r)
         @> array['not_legalised_outside_eu']
     and not (select r.reasons from public.risk_from_signals(
            9000, 9000, 2026, 6000, 'x', 'Lisboa', true, false, null, null,
            'imported', null, 0, null, array['not_legalised_outside_eu']) r)
         @> array['imported'], 'replaces imported';
  assert (select r.risk_score from public.risk_from_signals(
            9000, 9000, 2020, 6000, 'x', 'Lisboa', true, false, null, null,
            null, null, 0, null, array['not_legalised']) r) = 15, '15 points';
  assert (select r.risk_score from public.risk_from_signals(
            9000, 9000, 2020, 6000, 'x', 'Lisboa', true, false, null, null,
            null, null, 0, null, array['not_legalised_outside_eu']) r) = 20, '20 points';
end $$;

-- The CBR650R from England among Portuguese ones at about 9 000 €.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, status, description)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.mileage, v.price, 'Lisboa', 'active', v.description
from public.motorcycles m,
     (values
       ('uk',  2024, 6000, 8000,
        'Matriculada em Inglaterra. Falta proceder à legalização e matrícula em Portugal.'),
       ('pt',  2024, 6000, 8000, 'Matrícula portuguesa, revisões na marca.'),
       ('c1', 2024, 6000, 9000, null),
       ('c2', 2024, 6000, 9000, null),
       ('c3', 2024, 6000, 9000, null),
       ('c4', 2024, 6000, 9000, null),
       ('c5', 2024, 6000, 9000, null)
     ) v(sid, year, mileage, price, description)
where m.slug = 'honda-cbr650r';

select public.recalculate_deal_scores();

do $$
declare
  uk jsonb := (select score_breakdown from public.listings where source_listing_id = 'uk');
  pt jsonb := (select score_breakdown from public.listings where source_listing_id = 'pt');
  cost numeric := public.motorcycle_isv(
    (select coalesce(engine_cc_max, engine_cc_min) from public.motorcycles
     where slug = 'honda-cbr650r')) + 225 + 8000 * 0.30;
begin
  assert (uk ->> 'legalisation_cost')::numeric = round(cost),
    format('cost, got %s', uk ->> 'legalisation_cost');
  assert (uk ->> 'legalised_value')::numeric
         = round((uk ->> 'market_price')::numeric - cost),
    format('value, got %s', uk ->> 'legalised_value');
  assert (uk ->> 'pct_below_legalised_value')::numeric < 0, 'dearer than legalised value';
  assert (uk -> 'scores' ->> 'price')::numeric < 50,
    format('price slice, got %s', uk -> 'scores' ->> 'price');
  assert (pt -> 'scores' ->> 'price')::numeric > 70, 'the Portuguese one is a good price';
  assert pt ->> 'legalisation_cost' is null and pt ->> 'legalised_value' is null,
    'nothing for a Portuguese one';
  assert (select deal_score from public.listings where source_listing_id = 'uk')
         < (select deal_score from public.listings where source_listing_id = 'pt') - 15,
    'much lower than the same bike legalised';
  assert uk -> 'risk_reasons' ? 'not_legalised_outside_eu', 'risk reason';
  assert (select public.market_position(l) from public.listings l where source_listing_id = 'uk')
         = (uk ->> 'pct_below_legalised_value')::numeric, 'market position';
end $$;

-- Cheap enough even after legalising: still at most 79.
update public.listings set price = 3000 where source_listing_id = 'uk';
select public.recalculate_deal_scores();

do $$
declare
  uk jsonb := (select score_breakdown from public.listings where source_listing_id = 'uk');
begin
  assert (select deal_score from public.listings where source_listing_id = 'uk') = 79,
    format('capped, got %s', (select deal_score from public.listings where source_listing_id = 'uk'));
  assert (uk ->> 'capped_for_legalisation')::boolean, 'flagged';
  assert not (uk ->> 'capped_for_damage')::boolean, 'not for damage';
end $$;
