-- More equipment read from the ads (Rafael, 2026-10-20: short licence
-- plate holder, frame sliders called "cogumelos", tinted screen, original
-- parts included...): new
-- codes, and more of the words sellers use for the existing ones. Codes
-- never change (saved searches store them); the app's extraLabels lists
-- the same codes.
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
        '(akrapovi|termignoni|sc[\s-]?project|yoshimura|leovince|\mmivv\M|\marrow\M'
        '|\mgpr\M|bodis|\mzard\M|giannelli|\mremus\M|two\s+brothers|austin\s+racing'
        '|hp\s+corse|\mixil\M|scorpion|ponteiras?\s+(de\s+escape|desportiv)'
        '|escape\s+(\w+\s+)?(desportivo|racing|completo|de\s+competi|after\s*-?\s*market))'),
      ('luggage',
        '(top\s*-?\s*case|\mmalas\M|malas?\s+laterais|alforges|\mba[uú]\M'
        '|malas?\s+(de\s+)?dep[oó]sito|sacos?\s+de\s+dep[oó]sito|tank\s*-?\s*bag'
        '|porta[\s-]*bagagens?|grelha\s+traseira|suporte\s+(de\s+|para\s+)?(malas?|top))'),
      ('heated_grips',
        '(punhos\s+(aquecidos|t[eé]rmicos)|manoplas\s+aquecidas'
        '|aquecimento\s+(de|dos|nos)\s+punhos)'),
      ('protection',
        '(crash\s*-?\s*(pads?|bars?)|\msliders?\M|cogumelos|\mprote[cç][oõ]es\M'
        '|barras?\s+de\s+prote|tank\s*-?\s*pad|grelha\s+(de\s+|do\s+)?radiador'
        '|prote[cç][cç]?[aã]o\s+(de\s+|do\s+|da\s+|dos\s+|das\s+)?(motor|quadro|c[aá]rter|radiador|dep[oó]sito|punhos?|m[aã]os|manetes?|corrente|farol|escape)'
        '|protetor(es)?\s+(de\s+|do\s+|da\s+|dos\s+|das\s+)?(motor|quadro|c[aá]rter|radiador|dep[oó]sito|punhos?|m[aã]os|manetes?|corrente|farol|escape))'),
      ('new_tyres',
        '(pneus?\s+(\w+\s+){0,2}(novos?|recentes?)\M|pneus?\s+(mudad|trocad|substitu[ií]d)'
        '|(mudou|trocou|colocou|meteu)\s+pneus)'),
      ('tail_tidy',
        '(suporte\s+curto|(suporte|porta)[\s-]*(de\s+|da\s+)?matr[ií]culas?\s+(curt|desportiv|regul[aá]v)'
        '|matr[ií]cula\s+curta|eliminador\s+(de\s+|do\s+)?guarda[\s-]*lamas|tail\s*-?\s*tidy)'),
      ('screen',
        '((bolha|viseira|para[\s-]*brisas?|ecr[aã])\s+(\w+\s+)?'
        '(fumad|fum[eê]|escurecid|escur|desportiv|alt[ao]|touring|racing|puig|ermax|\mmra\M))'),
      ('levers',
        -- also misspelt ("manteres curtas")
        '(\mmane?te?r?e?s?\s+(\w+\s+)?(ajust[aá]ve|regul[aá]ve|curt|desportiv|articulad|rizoma|puig|\mcnc\M))'),
      ('mirrors',
        '(espelhos?\s+(\w+\s+)?(de\s+|na\s+)?(ponta|bar[\s-]*end|rizoma)'
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
        '|\morigina(l|is)\s+(inclu|tamb[eé]m|acompanha))')
  )
  select coalesce(array_agg(r.code order by r.code), '{}'::text[])
  from rules r, t
  where t.text ~ r.pattern
$$;

alter table public.saved_searches
  drop constraint saved_searches_extras_check;

alter table public.saved_searches
  add constraint saved_searches_extras_check
    check (extras <@ array['quickshifter', 'exhaust', 'luggage', 'heated_grips',
                           'protection', 'new_tyres', 'tail_tidy', 'screen',
                           'levers', 'mirrors', 'phone_mount', 'alarm',
                           'steering_damper', 'centre_stand', 'cruise_control',
                           'suspension', 'led_indicators', 'passenger_grips',
                           'original_parts']);
