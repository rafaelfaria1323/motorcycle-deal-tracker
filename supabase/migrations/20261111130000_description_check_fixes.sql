-- Fixes from the first description check (N.55, 2026-11-11): Gemini's
-- reading of 60 ads against the rules. Each change has its phrase in
-- supabase/tests/description_check_fixes_test.sql.
--
-- Mileage in the text: "25,673 km" (thousands with a comma) read 673,
-- "Ano 2025 Km 7.500" read the year, "Km 7.500" without a colon and
-- "10mil/km" were not read, and "A monta conta com 3550 km" took the typo
-- "monta" for fitting work. Extras: a full exhaust line ("linha de escape
-- completa", Dominator, "Arkapovick"), cases by name ("mala Shad"), side
-- protectors, tyres "foram trocados", screens ("vidro Givi", "defletor"),
-- "espelhos de punho" and the original parts that come with the bike
-- ("segue todo o material original"). Damage: "danos de queda" and brakes
-- or discs needed.

-- "25,673 km": a comma before three digits groups thousands.
create or replace function public.mileage_number(p_number text, p_thousands boolean)
returns numeric
language sql
immutable
set search_path = ''
as $_$
  select v
  from (
    select case
      when p_thousands then
        replace(regexp_replace(p_number, '\s', '', 'g'), ',', '.')::numeric
        * 1000
      when p_number ~ '^\d+[.,]\d{1,2}$' then null
      else regexp_replace(p_number, '[.,\s]', '', 'g')::numeric
    end as v
  ) x
  where v <= 300000
$_$;

create or replace function public.mileage_in_text(p_description text)
returns integer
language plpgsql
immutable
set search_path = ''
as $_$
declare
  d      constant text := lower(coalesce(p_description, ''));
  -- "25,673" groups thousands with a comma (a decimal has 1-2 digits).
  num    constant text :=
    '(\d{1,3}(?:[.\s]\d{3})+|\d{1,3}(?:,\d{3})+(?!\d)|\d+(?:[.,]\d{1,2})?)';
  -- A unit not followed by "/h", "por mês", "de autonomia" or a verb
  -- ("com 15.000 km troquei a corrente").
  unit   constant text :=
    '\s*(mil)?\s*/?\s*(?:km|kms|quil[oó]metros)\M'
    '(?!\s*(?:/|por\M|p/|h\M|de\s+autonomia'
    '|tro[cq]u|mud[aeoá]|substitu|instal|coloc|coloqu|mont[aeo]'
    '|f[ie]z\M|foi\M|foram\M|lev[eo]|meti\M|pus\M))';
  other  constant text :=
    '(pneu|revis|[óo]leo|corrente|\mkit|garantia|autonomia|pr[oó]xim|troc'
    '|mud[aeo]|embraiag|pastilh|trav[õoã]|filtro|\mvelas?\M|\mcada\M'
    '|[uú]ltim|manuten|servi[çc]o|feit[ao]|bateria|viage|percurso'
    '|tro[cq]u|substitu|instal|coloc|coloqu|\mmont(?:ei|ou|ad|ar|ag)|\mcompr[aeo]'
    '|\mfiz\M|inspe[çc]|check|\mipo\M|afina|lubrific'
    '|\m(?:aos|dos|os|nos|[àa]s|das|at[eé]|h[aá]|faz)\s*$'
    '|(?:menos|mais)\s+de\s*$)';
  leads  constant text :=
    '(?:\mtem|\mcom|apenas|\ms[oó]|c/|quilometragem|marca)\s*$';
  r      record;
  n      numeric;
  led    integer[] := '{}'::integer[];
  plain  integer[] := '{}'::integer[];
begin
  -- "... com 12.000 km": the clause before the number, the number, "mil".
  for r in
    select x.m
    from regexp_matches(d, '([^.,;:!?\n]*?)\m' || num || unit, 'g') as x(m)
  loop
    continue when right(r.m[1], 50) ~ other;
    n := public.mileage_number(r.m[2], r.m[3] is not null);
    continue when n is null;
    if r.m[1] ~ leads then led := led || n::integer;
    else plain := plain || n::integer;
    end if;
  end loop;

  -- "Quilometragem: 12000", "Kms: 12.000", also without the colon
  -- ("Ano 2025 Km 7.500"), where a year is not the mileage ("12.000 km
  -- 2019").
  for r in
    select x.m
    from regexp_matches(d,
      '(?:quilometragem\s*([:=-])?|(?:quil[oó]metros|\mkms?)\s*([:=-])?)\s*'
      || num || '\s*(mil)?\M', 'g') as x(m)
  loop
    continue when r.m[1] is null and r.m[2] is null
      and r.m[3] ~ '^(19|20)\d\d$';
    n := public.mileage_number(r.m[3], r.m[4] is not null);
    continue when n is null;
    led := led || n::integer;
  end loop;

  if cardinality(led) > 0 then
    plain := led;
  end if;
  if (select count(distinct v) from unnest(plain) v) = 1 then
    return plain[1];
  end if;
  return null;
end;
$_$;

create or replace function public.listing_extras(p_variant text, p_description text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             lower(coalesce(p_variant, '') || ' ' || coalesce(p_description, '')),
             '\msem\s+(o\s+|a\s+|os\s+|as\s+)?\w+', ' ', 'g'
           ) as text
  ),
  rules(code, pattern) as (
    values
      ('quickshifter', '(quick\s*-?\s*shift|\mshifter\M|blipper)'),
      ('exhaust',
        '(akrapovi|arkapovi|dominator|linha\s+(de\s+escape\s+)?completa|termignoni|sc[\s-]?project|yoshimura|leovince|\mmivv\M|\marrow\M'
        '|\mgpr\M|bodis|\mzard\M|giannelli|\mremus\M|two\s+brothers|austin\s+racing'
        '|hp\s+corse|\mixil\M|scorpion|ponteiras?\s+(de\s+escape|desportiv)'
        '|escape\s+(\w+\s+)?(desportivo|racing|completo|de\s+competi|after\s*-?\s*market))'),
      ('luggage',
        '(top\s*-?\s*case|\mmalas\M|malas?\s+laterais|alforges|\mba[uú]\M'
        '|malas?\s+(de\s+)?dep[oó]sito|sacos?\s+de\s+dep[oó]sito|tank\s*-?\s*bag'
        '|top\s*-?\s*box|\mmala\s+(\w+\s+){0,3}(shad|givi|kappa|traseira|lateral|top)|porta[\s-]*bagagens?|grelha\s+traseira|suporte\s+(de\s+|para\s+)?(malas?|top))'),
      ('heated_grips',
        '(punhos\s+(aquecidos|t[eé]rmicos)|manoplas\s+aquecidas'
        '|aquecimento\s+(de|dos|nos)\s+punhos)'),
      ('protection',
        '(crash\s*-?\s*(pads?|bars?)|\msliders?\M|cogumelos|\mprote[cç][oõ]es\M'
        '|barras?\s+de\s+prote|tank\s*-?\s*pad|grelha\s+(de\s+|do\s+)?radiador'
        -- engine covers and protectors by their makers
        '|gb\s*-?\s*racing|tampas?\s+(de\s+|do\s+)?(motor|embraiagem|alternador)\s+(\w+\s+)?(carbono|prote|racing)'
        '|prote[cç][cç]?[aã]o\s+(de\s+|do\s+|da\s+|dos\s+|das\s+)?(motor|quadro|c[aá]rter|radiador|dep[oó]sito|punhos?|m[aã]os|manetes?|corrente|farol|escape|peseiras?|calcanhar(es)?|pedais)'
        '|(protetor(es)?|prote[cç][oõ]es)\s+laterais'
        '|protetor(es)?\s+(de\s+|do\s+|da\s+|dos\s+|das\s+)?(motor|quadro|c[aá]rter|radiador|dep[oó]sito|punhos?|m[aã]os|manetes?|corrente|farol|escape|peseiras?|calcanhar(es)?|pedais))'),
      ('new_tyres',
        '(pneus?\s+(\w+\s+){0,2}(novos?|recentes?)\M|pneus?\s+(mudad|trocad|substitu[ií]d)'
        '|pneus?\s+(foram|s[aã]o)\s+(novos|mudad|trocad|substitu[ií]d)'
        '|(mudou|trocou|colocou|meteu)\s+pneus)'),
      ('tail_tidy',
        '(suporte\s+curto|(suporte|porta)[\s-]*(de\s+|da\s+)?matr[ií]culas?\s+(\w+\s+)?(curt|desportiv|regul[aá]v|lightech|rizoma|evotech|puig|barracuda|highsider|gilles|bonamici|r\s*&\s*g\M)'
        '|matr[ií]cula\s+curta|eliminador\s+(de\s+|do\s+)?guarda[\s-]*lamas|tail\s*-?\s*tidy)'),
      ('screen',
        '((bolha|viseira|para[\s-]*brisas?|ecr[aã]|vidro)\s+(\w+\s+){0,2}'
        '(fumad|fum[eê]|escurecid|escur|desportiv|alt[ao]|touring|racing|puig|ermax|\mmra\M|givi|kappa)'
        -- a deflector is an added screen ("defletor frontal", "fly screen")
        '|\mde(f|fl)e[cç]?tor(es)?\M|fly\s*-?\s*screen)'),
      ('levers',
        -- also misspelt ("manteres curtas")
        '(\mmane?te?r?e?s?\s+(\w+\s+)?(ajust[aá]ve|regul[aá]ve|curt|desportiv|articulad|rizoma|puig|\mcnc\M|gilles|lightech|bonamici|evotech|\mlsl\M|valter))'),
      ('mirrors',
        '(espelhos?\s+(\w+\s+)?(de\s+|na\s+)?(ponta|punho|bar[\s-]*end|rizoma)'
        '|retrovisores?\s+(\w+\s+)?(de\s+|na\s+)?(ponta|bar[\s-]*end|rizoma))'),
      ('phone_mount',
        '(suporte\s+(de\s+|para\s+)?(telem[oó]vel|smartphone|telefone|gps)'
        '|quad\s*-?\s*lock|carregador\s+usb|tomada\s+usb|\musb\M)'),
      ('alarm', '(\malarme\M|mapit|localizador)'),
      ('steering_damper', '(amortecedor\s+de\s+dire[cç]|steering\s+damper)'),
      ('centre_stand', 'descanso\s+central'),
      ('cruise_control',
        '(cruise\s*-?\s*control|controlo\s+de\s+velocidade|velocidade\s+de\s+cruzeiro)'),
      ('suspension',
        '([öo]hlins|k[\s-]?tech|wilbers|hyperpro|matris|andreani'
        '|suspens[aã]o\s+(\w+\s+)?(afinad|melhorad|upgrade|revista))'),
      ('led_indicators', '((piscas?|indicadores)\s+(\w+\s+)?led\M)'),
      ('passenger_grips',
        '((suporte|pegas?|apoios?|al[cç]as?)\s+(\w+\s+){0,2}m[aã]os\s+(\w+\s+){0,2}pendura'
        '|(pegas?|al[cç]as?)\s+(\w+\s+){0,2}pendura|grab\s*-?\s*rails?)'),
      -- The parts taken off come with the bike, so it can go back to stock.
      ('original_parts',
        '((partes|pe[cç]as)\s+(\w+\s+)?(de\s+origem|originais)'
        '|(inclui|acompanha|entrego|entrega|oferece|vai\s+com|com)\s+(\w+\s+){0,3}(de\s+origem|originais)'
        '|\morigina(l|is)\s+(inclu|tamb[eé]m|acompanha)'
        -- "segue todo o material original", "vem com o vidro original"
        '|material\s+(\w+\s+)?(original|de\s+origem)'
        '|\m(vem|segue|seguem|vai|v[aã]o)\s+(\w+\s+){0,4}(original|originais|de\s+origem)\M)')
  )
  select coalesce(array_agg(r.code order by r.code), '{}'::text[])
  from rules r, t
  where t.text ~ r.pattern
$$;

create or replace function public.mentions_accident(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 lower(coalesce(p_description, '')),
                 '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|\mnenhu\w*|livre\s+de|\mzero\M|isent[ao]\s+de)'
                 '\s+([^\s.,!?;]+\s+){0,3}?(sinistr\w*|acident\w*|danos?|batid[ao]s?|bateu'
                 '|quedas?|ca[ií]u|ca[ií]d[ao]s?|toques?|tomb\w*|embat\w*|colis\w*|colidiu'
                 '|pancadas?|derrap\w*|ao\s+ch[ãa]o)',
                 ' ', 'g'),
               -- Insurance wording: "seguro contra todos os riscos e sinistros".
               'seguro\s+.{0,40}sinistr\w*', ' ', 'g'),
             -- Prices fall too: "o preço caiu", "baixou".
             '(pre[çc]o|valor)\s+(\w+\s+){0,2}?ca[ií]u', ' ', 'g') as d
  )
  select d ~ '(sinistr|acident|batid[ao]|\mbateu\M|\mca[ií]u\M|\mca[ií]d[ao]\M|\mtomb(ou|ad[ao])\M'
             '|\membat|colis[ãa]o|colidiu|ao\s+ch[ãa]o|derrap'
             -- "danos de queda"
             '|\mdanos?\s+(de|da|por)\s+(uma\s+)?queda)'
      or d ~ '\m(teve|sofreu|deu|levou|apanhou)\s+(um|uma)\s+(\w+\s+)?'
             '(toque|toquezinho|pancada|queda|tombo|batida|embate)'
  from t
$$;

create or replace function public.needs_repair(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with parts(p) as (
    select '(pisca|espelho|retrovisor|manete|carenage|farol|farolim|guarda-?lamas'
           '|suporte|ponteira|tampa|banco|pl[áa]stic|pe[çc]a|quadro|jante|para-?brisas?'
           '|bolha|pedal|poisa-?p[ée]s|sele[ct]?or|punho|escape|radiador|forquilha'
           '|guiador|dep[óo]sito|painel|matr[íi]cula|tanque|motor|embraiagem|caixa'
           -- brakes: "necessita de travão traseiro e disco"
           '|trav[ãaõo]|discos?\M)'
  ),
  t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   lower(coalesce(p_description, '')),
                   -- An electric start is not a broken part.
                   '(bot[ãa]o|ponto|sistema)\s+de\s+partida'
                   '|partida\s+(el[ée]c?trica|a\s+frio|autom[áa]tica)',
                   ' ', 'g'),
                 -- "não precisa de nada", "sem nada partido", "não falta nada".
                 '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|\mnenhu\w*|\mnada\M|livre\s+de|\mzero\M'
                 '|isent[ao]\s+de)\s+([^\s.,!?;]+\s+){0,3}?'
                 '(precis\w*|necessit\w*|carece\w*|partid\w*|amolgad\w*|danific\w*|danos?'
                 '|avari\w*|falt\w*|empenad\w*|repara\w*)',
                 ' ', 'g'),
               -- "ideal para quem precisa de uma mota", "se precisar de".
               '\m(quem|se)\s+(\w+\s+)?(precis|necessit)\w*', ' ', 'g'),
             -- "precisa de carta A2", "necessita de licença".
             '(precis|necessit)\w*\s+(\w+\s+){0,2}?(carta|licen[çc]a|habilita[çc][ãa]o|categoria)',
             ' ', 'g') as d
  )
  select d ~ ('(precis|necessit|carece)\w*\s+([^\s.,!?;]+\s+){0,3}?'
              '(repar|arranj|substitu|pintur|bate-?chapa|' || p || ')')
      or d ~ '\mpara\s+(reparar|arranjar|recuperar|pe[çc]as)\M'
      or d ~ '\mavari'
      or d ~ '\mn[ãa]o\s+(pega|trabalha|arranca)\M'
      or d ~ '(amolgad|empenad|danificad)'
      or d ~ '\mdanos?\s+(n[oa]s?|em)\M'
      or d ~ ('\mfalta(m|r)?\s+([^\s.,!?;]+\s+){0,3}?\m' || p)
      or d ~ ('\m' || p || '\w*\s+([^\s.,!?;]+\s+){0,2}?em\s+falta')
      or d ~ ('\m' || p || '\w*\s+([^\s.,!?;]+\s+){0,3}?partid[ao]s?\M')
      or d ~ '\m(est[áa]|ficou|vem|veio)\s+(\w+\s+)?partid[ao]s?\M'
  from t, parts
$$;

-- Live listings read again (the triggers fill them): the signals and
-- extras, and a mileage read from the text or missing.
update public.listings
set text_signals = null
where status in ('active', 'price_changed');

update public.listings
set mileage = null
where status in ('active', 'price_changed')
  and (mileage is null or mileage_from_text);

-- OLX sellers title the PCX 125 "PCX" ("Vendo pcx 2022"): another name
-- for a followed PCX 125, if one is in the catalog. Every import
-- re-checks the model of the ads it reads, so the stored ones follow.
update public.motorcycles
set aliases = aliases || array['PCX']
where lower(brand) = 'honda'
  and regexp_replace(lower(model), '[^a-z0-9]', '', 'g') = 'pcx125'
  and not 'PCX' = any(aliases);
