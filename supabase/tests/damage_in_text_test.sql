-- Damage in the description: falls and knocks (mentions_accident), repairs
-- and missing or broken parts (needs_repair), scratches (cosmetic_damage),
-- and the Deal Score's cap of 50 when the text tells of damage.

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
  assert r.risk_score = 80, format('accident 30 + repair 20 + cosmetic 5 + price 25, got %s', r.risk_score);
  assert r.reasons = array['possible_accident', 'price_below_market', 'needs_repair', 'cosmetic_damage'],
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

-- The cap: the damaged bike scores at most 50 and says why; the same bike
-- without damage in its text is not capped.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2023, 6000, v.price, 'Porto', v.description, 'active'
from public.motorcycles m,
     (values
       ('dmg', 5000, 'Teve um toque por trás, precisa do suporte de matrícula.'),
       ('ok',  5000, 'Sempre na garagem, revisões feitas.'),
       ('c1',  7000, null), ('c2', 7000, null), ('c3', 7000, null),
       ('c4',  7000, null), ('c5', 7000, null)
     ) v(sid, price, description)
where m.slug = 'yamaha-mt-07';

select public.recalculate_deal_scores();

do $$
declare
  dmg_score smallint := (select deal_score from public.listings where source_listing_id = 'dmg');
  dmg jsonb := (select score_breakdown from public.listings where source_listing_id = 'dmg');
  ok_score smallint := (select deal_score from public.listings where source_listing_id = 'ok');
  ok jsonb := (select score_breakdown from public.listings where source_listing_id = 'ok');
begin
  assert ok_score > 50, format('undamaged bike keeps its score, got %s', ok_score);
  assert dmg_score = 50, format('damaged bike capped at 50, got %s', dmg_score);
  assert (dmg ->> 'capped_for_damage')::boolean, 'cap flagged';
  assert not (ok ->> 'capped_for_damage')::boolean, 'no cap flagged';
  assert dmg -> 'risk_reasons' ? 'needs_repair', 'reason kept';
end $$;

do $$
begin
  assert public.damage_cap(array['possible_accident']) = 50, 'accident caps';
  assert public.damage_cap(array['needs_repair']) = 50, 'repair caps';
  assert public.damage_cap(array['cosmetic_damage', 'no_mileage']) is null, 'scratches do not cap';
  assert public.damage_cap('{}') is null, 'nothing, no cap';
end $$;
