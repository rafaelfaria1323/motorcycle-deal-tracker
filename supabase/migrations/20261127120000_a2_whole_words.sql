-- The A2 rule read "limitada" inside other words (N.122, Rafael: an MT-07
-- shown as an A2 version with nothing in its text saying so):
-- "ilimitada", "delimitado" counted as a limited bike. The limited forms
-- now count only as whole words. The app now shows the ad's title too
-- (the rule reads it with the description), so the reason can be seen.

create or replace function public.power_version(p_variant text, p_description text)
returns text
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 lower(concat_ws(' ', p_variant, p_description)),
                 -- Something that could be done, not what was done:
                 -- "pode ser limitada a 35 kW", "fácil de deslimitar",
                 -- "ideal para limitar", "kit A2 incluído".
                 '(pode(ndo)?\s+(ser|ficar|se)|possibilidade\s+de(\s+ser)?'
                 '|f[áa]cil(mente)?(\s+de)?|op[çc][ãa]o\s+de|preparad[ao]\s+para(\s+ser)?'
                 '|\mpara)\s+(\w+\s+){0,2}?(des)?(limit|bloque|restring)\w*'
                 '(\s+(a|para|em|aos?)\s+(35\s*kw|a2|\d+\s*(cv|hp)))?',
                 ' ', 'g'),
               '(des)?limit[áa]vel(\s+(a|para|em|aos?)\s+(35\s*kw|a2|\d+\s*(cv|hp)))?'
               '|kit\s+(de\s+)?(limita[çc][ãa]o|a2)\s+(inclu[íi]d[ao]|oferta|em\s+oferta|dispon[íi]vel|opcional)',
               ' ', 'g'),
             -- "não está limitada": said of a full-power bike.
             'n[ãa]o\s+(est[áa]\s+|[ée]\s+|vem\s+)?limitad[ao]\M',
             ' ', 'g') as d
  )
  select case
    when d ~ '(deslimit|desbloque|desrestring)\w*'
      or d ~ '(limita[çc][ãa]o|kit(\s+a2)?|restri[çc][ãa]o)\s+(foi\s+|j[áa]\s+)?(removid|retirad|tirad)'
      or d ~ '(estava|esteve|era|vinha)\s+(\w+\s+){0,2}?limitad'
      then 'a2_unlocked'
    when d ~ '(vers[ãa]o\s+full|full\s+power|pot[êe]ncia\s+(total|m[áa]xima|completa))'
      then null
    when d ~ '\mlimitad[ao]\M'
      or d ~ '\m35\s*kw'
      or d ~ 'vers[ãa]o\s+(a2|35)'
      or d ~ '\ma2\s+(limitad|kit|montad)'
      or d ~ 'kit\s+(de\s+)?(limita[çc][ãa]o|a2)\s+(montad|instalad|colocad)'
      then 'a2_limited'
  end
  from t
$$;

-- Live listings read again (the triggers fill the signals).
update public.listings
set text_signals = null
where status in ('active', 'price_changed');
