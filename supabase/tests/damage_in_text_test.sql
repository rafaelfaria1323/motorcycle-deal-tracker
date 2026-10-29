-- Damage in the description: falls and knocks (mentions_accident), repairs
-- and missing or broken parts (needs_repair), scratches (cosmetic_damage),
-- and how the Deal Score treats a damaged bike: its price against the
-- estimate less a repair allowance, at most 79.

-- The ad that started it (Honda ADV 350, Rafael's screenshot, paraphrased).
do $$
declare
  adv text := 'Honda ADV 350 de 2023, 8.000 km. Teve um toque por trás, '
              'precisa do suporte de matrícula e do pisca traseiro. '
              'Tem alguns riscos na carenagem. Resto impecável.';
  r record;
begin
  assert public.mentions_accident(adv), 'teve um toque';
  assert public.needs_repair(adv), 'precisa do suporte';
  assert public.cosmetic_damage(adv), 'riscos';

  select * into r from public.risk_assessment(8000, 10000, 2023, 8000, adv, 'Porto');
  -- 20 % below the undamaged 10 000, at the damaged value (20 % allowance).
  assert r.risk_score = 55, format('accident 30 + repair 20 + cosmetic 5, got %s', r.risk_score);
  assert r.reasons = array['possible_accident', 'needs_repair', 'cosmetic_damage'],
    format('reasons, got %s', r.reasons);
end $$;

-- Falls and knocks.
do $$
declare
  s text;
begin
  foreach s in array array[
    'Caiu parada no parque, nada de grave.',
    'A mota tombou na garagem.',
    'Foi ao chão a baixa velocidade.',
    'Derrapou numa rotunda.',
    'Sofreu um pequeno embate.',
    'Levou uma pancada no estacionamento.',
    'Teve uma pequena queda.',
    'Deu um tombo em 2023.',
    'Colisão traseira ligeira.'
  ] loop
    assert public.mentions_accident(s), format('accident: %s', s);
  end loop;

  foreach s in array array[
    'Nunca caiu.',
    'Nunca foi ao chão.',
    'Sem quedas, sem toques.',
    'Nenhum toque ou queda.',
    'Macia ao toque.',
    'Um toque desportivo.',
    'O preço caiu 500 euros.',
    'Sem colisões nem tombos.',
    'Tem um toque de classe.'
  ] loop
    assert not public.mentions_accident(s), format('no accident: %s', s);
  end loop;
end $$;

-- Repairs and parts.
do $$
declare
  s text;
begin
  foreach s in array array[
    'Precisa de reparação na embraiagem.',
    'Necessita de substituir a manete.',
    'Falta o espelho esquerdo.',
    'Faltam algumas peças.',
    'Pisca em falta.',
    'Tem o espelho partido.',
    'Carenagem lateral partida.',
    'A bolha está partida.',
    'Vendo para peças.',
    'Mota avariada.',
    'Não pega.',
    'Depósito amolgado.',
    'Guiador empenado.',
    'Tem danos na carenagem.'
  ] loop
    assert public.needs_repair(s), format('repair: %s', s);
  end loop;

  foreach s in array array[
    'Não precisa de nada, pronta a andar.',
    'Ideal para quem precisa de uma mota fiável.',
    'Precisa de carta A2 para conduzir.',
    'Nada partido, não falta nada.',
    'Sem danos.',
    'Sem avarias, nunca precisou de reparações.',
    'Partida elétrica, botão de partida no punho.',
    'Motor com partida a frio impecável.',
    'Vendo sem pressa, preço negociável.',
    'Suporte de matrícula curto.'
  ] loop
    assert not public.needs_repair(s), format('no repair: %s', s);
  end loop;
end $$;

-- Scratches.
do $$
declare
  s text;
begin
  foreach s in array array['Pequenos riscos no depósito.', 'Escape riscado.',
                           'Alguns arranhões.', 'Uma mossa no guarda-lamas.'] loop
    assert public.cosmetic_damage(s), format('scratches: %s', s);
  end loop;
  foreach s in array array['Sem riscos nem mossas.', 'Seguro contra todos os riscos.',
                           'Nenhum risco.', 'Riscas vermelhas de série.'] loop
    assert not public.cosmetic_damage(s), format('no scratches: %s', s);
  end loop;
end $$;

-- Two bikes of the same year and mileage, one with damage in its text:
-- priced like the others less its allowance it scores as they do; far
-- below that it ranks high, but never above 79.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2023, 6000, v.price, 'Porto', v.description, 'active'
from public.motorcycles m,
     (values
       ('dmg',   6300, 'Teve um toque por trás, precisa do suporte de matrícula.'),
       ('cheap', 4500, 'Teve um toque por trás, precisa do suporte de matrícula.'),
       ('ok',    7000, 'Sempre na garagem, revisões feitas.'),
       ('rep',   6300, 'Precisa do suporte de matrícula.'),
       ('c1',  7000, null), ('c2', 7000, null), ('c3', 7000, null),
       ('c4',  7000, null), ('c5', 7000, null)
     ) v(sid, price, description)
where m.slug = 'yamaha-mt-07';

select public.recalculate_deal_scores();

do $$
declare
  dmg jsonb := (select score_breakdown from public.listings where source_listing_id = 'dmg');
  cheap jsonb := (select score_breakdown from public.listings where source_listing_id = 'cheap');
  ok jsonb := (select score_breakdown from public.listings where source_listing_id = 'ok');
  rep jsonb := (select score_breakdown from public.listings where source_listing_id = 'rep');
  cheap_score smallint := (select deal_score from public.listings where source_listing_id = 'cheap');
  cheap_risk smallint := (select risk_score from public.listings where source_listing_id = 'cheap');
begin
  -- Accident and repair: 20 % off the 7 000 estimate = 5 600.
  assert (dmg ->> 'market_price')::numeric = 7000, format('undamaged estimate kept, got %s', dmg ->> 'market_price');
  assert (dmg ->> 'damage_allowance')::numeric = 0.20, format('allowance, got %s', dmg ->> 'damage_allowance');
  assert (dmg ->> 'damaged_value')::numeric = 5600, format('damaged value, got %s', dmg ->> 'damaged_value');
  assert (dmg ->> 'pct_below_damaged_value')::numeric = -12.5, format('pct, got %s', dmg ->> 'pct_below_damaged_value');
  -- A repair to do only: 10 %.
  assert (rep ->> 'damaged_value')::numeric = 6300, format('repair only, got %s', rep ->> 'damaged_value');
  -- 4 500 is 19.6 % below 5 600: ranks high, capped at 79.
  assert cheap_score = 79, format('cheap damaged bike capped at 79, got %s', cheap_score);
  assert (cheap ->> 'capped_for_damage')::boolean, 'cap flagged';
  -- Still 19.6 % below its damaged value: that is worth a look.
  assert cheap -> 'risk_reasons' ? 'price_below_market', 'below its damaged value';
  assert cheap_risk = 75, format('accident 30 + repair 20 + price 25, got %s', cheap_risk);
  assert not (ok ->> 'capped_for_damage')::boolean, 'no cap flagged';
  assert ok ->> 'damage_allowance' is null, 'no allowance without damage';
  assert (select deal_score from public.listings where source_listing_id = 'dmg')
         < (select deal_score from public.listings where source_listing_id = 'ok'),
         'damaged bike above its damaged value scores below the undamaged one';
end $$;

do $$
begin
  assert public.damage_cap(array['possible_accident']) = 79, 'accident caps';
  assert public.damage_cap(array['needs_repair']) = 79, 'repair caps';
  assert public.damage_cap(array['cosmetic_damage', 'no_mileage']) is null, 'scratches do not cap';
  assert public.damage_cap('{}') is null, 'nothing, no cap';
  assert public.damage_allowance(array['possible_accident']) = 0.15, 'accident 15 %';
  assert public.damage_allowance(array['needs_repair']) = 0.10, 'repair 10 %';
  assert public.damage_allowance(array['needs_repair', 'possible_accident']) = 0.20, 'both 20 %';
  assert public.damage_allowance(array['cosmetic_damage']) = 0, 'scratches, none';
end $$;
