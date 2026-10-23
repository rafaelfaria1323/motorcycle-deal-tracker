-- A single owner written in the ad's title or description counts as
-- first_owner when the ad has no number of registrations.
do $$
declare
  s text;
  r record;
begin
  foreach s in array array[
    'Primeiro dono, sempre na garagem.',
    'Único dono.',
    'Unico e primeiro dono',
    'Mota de dono único.',
    'Teve apenas 1 dono.',
    'Um só dono, revisões na marca.',
    '1º dono',
    'Vendo em 1ª mão.',
    'Primeira mão, nacional.',
    'Primeiro proprietário.',
    'First owner, full service history.',
    'One owner from new.'
  ] loop
    assert public.single_owner_in_text(null, s), format('single owner: %s', s);
  end loop;
  assert public.single_owner_in_text('Honda CB650R único dono', null), 'in the title';

  foreach s in array array[
    'Não é primeiro dono.',
    'Nunca foi de um único dono.',
    'Segundo dono.',
    'Teve 2 donos.',
    'Sou o dono há 3 anos.',
    'Ideal para quem procura a primeira mota.',
    'Not the first owner.'
  ] loop
    assert not public.single_owner_in_text(null, s), format('not single owner: %s', s);
  end loop;

  -- No field: the text gives it.
  select * into r from public.risk_assessment(8000, 8000, 2022, 10000,
    'Único dono, sempre na garagem.', 'Porto');
  assert r.reasons = array['first_owner'], format('from the text, got %s', r.reasons);
  assert r.risk_score = 0, 'floor 0';

  -- The field says 2 owners: the text doesn't count.
  select * into r from public.risk_assessment(8000, 8000, 2022, 10000,
    'Único dono, sempre na garagem.', 'Porto', p_registrations => 2);
  assert not r.reasons @> array['first_owner'], format('the field wins, got %s', r.reasons);

  -- The field says 1: as before, once.
  select * into r from public.risk_assessment(8000, 8000, 2022, 10000,
    'Primeiro dono.', 'Porto', p_registrations => 1);
  assert r.reasons = array['first_owner'], format('once, got %s', r.reasons);
end $$;
