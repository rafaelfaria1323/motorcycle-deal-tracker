-- N.135: Honda's E-Clutch as an extra (`e_clutch`), worth a point like
-- the quickshifter; the card shows it in green, and Ofertas' equipment
-- filter and saved searches find it.

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
        '|\m(vem|segue|seguem|vai|v[aã]o)\s+(\w+\s+){0,4}(original|originais|de\s+origem)\M)'),
      -- Honda's E-Clutch (CB650R and CBR650R from 2024): the clutch works
      -- by itself, the gears stay manual. "sem e-clutch" is stripped above.
      ('e_clutch', '(\me\s*-?\s*clutch\M|embraiagem\s+(autom[aá]tica\s+)?elec?tr[oó]nica)')
  )
  select coalesce(array_agg(r.code order by r.code), '{}'::text[])
  from rules r, t
  where t.text ~ r.pattern
$$;

create or replace function public.valued_extras(p_extras text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(e order by e), '{}'::text[])
  from unnest(p_extras) e
  where e = any (array['quickshifter', 'exhaust', 'luggage', 'heated_grips',
                       'suspension', 'cruise_control', 'steering_damper',
                       'new_tyres', 'e_clutch'])
$$;

-- Only the ads that can name it read their extras again (the trigger fills
-- them); the next run's scores carry them into the breakdown.
update public.listings
set text_extras = null
where status in ('active', 'price_changed')
  and concat_ws(' ', variant, description) ~* '(clutch|embraiagem)';
