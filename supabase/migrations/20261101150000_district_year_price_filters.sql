-- Ofertas' and saved searches' place filter (F.11, feature review 1.6),
-- and two more bounds (1.7). The free-text "Localização" matched any
-- place containing the words ("Porto" also found "Porto de Mós") and
-- missed other spellings; a district is chosen from a list instead. Each
-- place gets its district (the 18 districts and the two autonomous
-- regions): GeoNames' first-level division of the same town (the npm
-- package cities.json 1.1.65, as the places themselves; CC BY 4.0), else
-- of the municipality of that name, else of the nearest town; the
-- districts' own names are themselves. The computed field
-- listings.district reads the listing's place the way the distance does
-- (place_key), null when the place is unknown.

create function public.district_names()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['Aveiro', 'Beja', 'Braga', 'Bragança', 'Castelo Branco', 'Coimbra', 'Évora', 'Faro', 'Guarda', 'Leiria', 'Lisboa', 'Portalegre', 'Porto', 'Santarém', 'Setúbal', 'Viana do Castelo', 'Vila Real', 'Viseu', 'Açores', 'Madeira']
$$;

alter table public.places
  add column district text check (district = any (public.district_names()));

update public.places set district = 'Aveiro' where key in (
  'aguada de cima', 'agueda', 'albergaria a velha', 'anadia', 'aradas', 'argoncilhe',
  'arouca', 'arrifana', 'avanca', 'aveiro', 'barro', 'beduido',
  'branca', 'cacia', 'castelo de paiva', 'cortegaca', 'cucujaes', 'eirol',
  'eixo', 'esgueira', 'esmoriz', 'espargo', 'espinho', 'estarreja',
  'feira', 'fiaes', 'gafanha', 'gafanha da encarnacao', 'ilhavo', 'lamas',
  'lobao', 'lourosa', 'luso', 'macieira de cambra', 'marco da oliveirinha', 'mealhada',
  'milheiros de poiares', 'mosteiro', 'murtosa', 'nariz', 'nogueira da regedoura', 'oia',
  'oliveira de azemeis', 'oliveira do bairro', 'oliveirinha', 'ovar', 'pacos de brandao', 'palhaca',
  'pampilhosa', 'pardilho', 'quinta do gato', 'rio meao', 'salreu', 'sanfins',
  'sangalhos', 'santa maria da feira', 'sao joao', 'sao joao da madeira', 'sao joao de ver', 'sever do vouga',
  'silvalde', 'sol posto', 'souto', 'vagos', 'vale de cambra', 'valega',
  'vila cha', 'vilar');
update public.places set district = 'Beja' where key in (
  'aldeia nova', 'aljustrel', 'almodovar', 'almograve', 'alvito', 'barrancos',
  'beja', 'beringel', 'boavista dos pinheiros', 'cabeca gorda', 'castro verde', 'cuba',
  'ferreira do alentejo', 'mertola', 'minas de sao domingos', 'moura', 'neves', 'odemira',
  'ourique', 'penedo gordo', 'salvada', 'sao luis', 'sao teotonio', 'senhora da graca dos padroes',
  'serpa', 'vidigueira', 'vila nova de milfontes', 'zambujeira do mar');
update public.places set district = 'Braga' where key in (
  'adaufe', 'amares', 'apulia', 'apulia e fao', 'aroes', 'aveleda',
  'bairro novo', 'barcelos', 'barqueiros', 'braga', 'brito', 'cabeceiras de basto',
  'caldas de vizela', 'caldelas', 'calendario', 'candoso', 'celorico de basto', 'chavao',
  'cristelo', 'esporoes', 'esposende', 'fafe', 'faria', 'fradelos',
  'frossos', 'galegos', 'gondizalves', 'gualtar', 'gueral', 'guimaraes',
  'guisande', 'joane', 'lago', 'macieira de rates', 'marinhas', 'mariz',
  'merelim', 'mire de tibaes', 'moreira de conegos', 'negreiros', 'nine', 'oliveira',
  'palmeira', 'perelhal', 'ponte', 'povoa de lanhoso', 'prado', 'real',
  'refojos de basto', 'rendufe', 'riba de ave', 'ribeirao', 'ronfe', 'sande',
  'selho', 'semelhe', 'serzedelo', 'sobreposta', 'tadim', 'taipas',
  'tebosa', 'terras de bouro', 'urgeses', 'varzea', 'vieira do minho', 'vila frescainha',
  'vila nova de famalicao', 'vila seca', 'vila verde', 'vilaca', 'vilar de figos', 'vizela');
update public.places set district = 'Bragança' where key in (
  'alfandega da fe', 'belver', 'braganca', 'braganca municipality', 'carrazeda de anciaes', 'carrazeda de ansiaes',
  'freixo de espada a cinta', 'macedo de cavaleiros', 'miranda do douro', 'mirandela', 'mogadouro', 'samil',
  'sendim', 'torre de moncorvo', 'vila flor', 'vimioso', 'vinhais');
update public.places set district = 'Castelo Branco' where key in (
  'alcains', 'aldeia de joanes', 'belmonte', 'castelo branco', 'covilha', 'fundao',
  'idanha a nova', 'oleiros', 'penamacor', 'proenca a nova', 'serta', 'teixoso',
  'vila de rei', 'vila velha de rodao');
update public.places set district = 'Coimbra' where key in (
  'alfarelos', 'alhadas', 'anca', 'antanhol', 'arazede', 'arganil',
  'assafarge', 'bairro do loreto', 'buarcos', 'cantanhede', 'carapinheira', 'castelo viegas',
  'coimbra', 'condeixa a nova', 'eiras', 'figueira da foz', 'gois', 'lavos',
  'lorvao', 'lousa', 'mira', 'miranda do corvo', 'montemor o velho', 'oliveira do hospital',
  'oliveira do mondego', 'pampilhosa da serra', 'penacova', 'penela', 'poiares', 'ribeira de frades',
  'santa clara', 'santo antonio dos olivais', 'sao martinho do bispo', 'sao paulo de frades', 'sao pedro de alva', 'soure',
  'tabua', 'tavarede', 'tocha', 'travanca', 'vila nova de poiares');
update public.places set district = 'Évora' where key in (
  'alandroal', 'arraiolos', 'borba', 'estremoz', 'evora', 'montemor o novo',
  'mora', 'mourao', 'portel', 'redondo', 'reguengos de monsaraz', 'vendas novas',
  'viana do alentejo', 'vila vicosa');
update public.places set district = 'Faro' where key in (
  'albufeira', 'alcantarilha', 'alcoutim', 'algoz', 'aljezur', 'almancil',
  'altura', 'alvor', 'armacao de pera', 'bensafrim', 'boliqueime', 'cabanas de tavira',
  'carvoeiro', 'castro marim', 'conceicao', 'estoi', 'estombar', 'faro',
  'ferragudo', 'ferreiras', 'fuzeta', 'guia', 'lagos', 'loule',
  'luz', 'manta rota', 'marmelete', 'mexilhoeira grande', 'moncarapacho', 'monchique',
  'monte gordo', 'olhao', 'olhos de agua', 'paderne', 'parchal', 'pera',
  'porches', 'portimao', 'quarteira', 'quelfes', 'sagres', 'santa barbara de nexe',
  'sao bartolomeu de messines', 'sao bras de alportel', 'sao marcos da serra', 'senhora da luz', 'silves', 'tavira',
  'tunes', 'vila do bispo', 'vila nova de cacela', 'vila real de santo antonio', 'vilamoura');
update public.places set district = 'Guarda' where key in (
  'aguiar da beira', 'almeida', 'celorico da beira', 'custoias', 'figueira de castelo rodrigo', 'fornos de algodres',
  'gouveia', 'guarda', 'loriga', 'manteigas', 'meda', 'pinhel',
  'sabugal', 'sao romao', 'seia', 'sequeira', 'trancoso', 'vila nova de foz coa');
update public.places set district = 'Leiria' where key in (
  'a dos francos', 'alcobaca', 'alfeizerao', 'aljubarrota', 'alqueidao da serra', 'alvaiazere',
  'alvorninha', 'amor', 'ansiao', 'atouguia da baleia', 'avelar', 'batalha',
  'benedita', 'boa vista', 'bombarral', 'caldas da rainha', 'caranguejeira', 'carreira',
  'castanheira de pera', 'cela', 'famalicao', 'ferrel', 'figueiro dos vinhos', 'foz do arelho',
  'gaeiras', 'juncal', 'leiria', 'loureira', 'lourical', 'maceira',
  'maceirinha', 'marinha grande', 'milagres', 'monte real', 'monte redondo', 'nadadouro',
  'nazare', 'obidos', 'olho marinho', 'pataias', 'pedrogao grande', 'peniche',
  'pombal', 'porto de mos', 'salir de matos', 'santa catarina da serra', 'sao martinho do porto', 'serra de el rei',
  'souto da carpalhosa', 'turquel', 'valado de frades', 'vestiaria', 'vidais', 'vieira de leiria');
update public.places set district = 'Lisboa' where key in (
  'a dos cunhados', 'abrigada', 'ajuda', 'alcabideche', 'alcantara', 'alcoentre',
  'alcoitao', 'alenquer', 'alfama', 'alfornelos', 'alfragide', 'alges',
  'algueirao', 'alhandra', 'almargem', 'alvalade', 'alvide', 'amadora',
  'anjos', 'apelacao', 'areeiro', 'arranho', 'arruda dos vinhos', 'aveiras de cima',
  'azambuja', 'azoia', 'azueira', 'bairro alto', 'bairro da madre de deus', 'bairro do alto da boavista',
  'baixa', 'barcarena', 'beato antonio', 'belas', 'belem', 'benfica',
  'bobadela', 'bucelas', 'buraca', 'cabanas de torres', 'cabo ruivo', 'cacem',
  'cadafais', 'cadaval', 'camarate', 'campelos', 'campo de ourique', 'campo grande',
  'campo pequeno', 'campolide', 'canecas', 'carcavelos', 'carnaxide', 'carnide',
  'carregado', 'cascais', 'castanheira do ribatejo', 'caxias', 'charneca', 'chelas',
  'cidade universitaria', 'cobre', 'colares', 'cova da moura', 'damaia', 'distrito de lisboa',
  'ericeira', 'estoril', 'falagueira', 'famoes', 'fanhoes', 'fontanelas',
  'graca', 'intendente', 'linda a velha', 'linho', 'lisboa', 'lisbon',
  'loures', 'lourinha', 'lumiar', 'mafra', 'malveira', 'marvila',
  'massama', 'meca', 'mem martins', 'milharado', 'moita dos ferreiros', 'monte estoril',
  'moscavide e portela', 'odivelas', 'oeiras', 'olhalvo', 'olivais', 'olival basto',
  'ota', 'paco de arcos', 'parede', 'parque das nacoes', 'pero pinheiro', 'pontinha',
  'porto salvo', 'povoa de santa iria', 'povoa de santo adriao', 'prazeres', 'principe real', 'prior velho',
  'queijas', 'queluz', 'ramada', 'restelo', 'rio de mouro', 'sacavem',
  'santa iria da azoia', 'santa maria de belem', 'santo antao do tojal', 'santo isidoro', 'santos o velho', 'sao domingos de rana',
  'sao joao da talha', 'sao joao das lampas', 'sao joao dos montes', 'sao jorge de arroios', 'sao juliao do tojal', 'sao mamede',
  'sao paulo', 'sao pedro da cadeira', 'sao sebastiao da pedreira', 'sete rios', 'silveira', 'sintra',
  'sobral de monte agraco', 'sobralinho', 'terrugem', 'torres vedras', 'ulgueira', 'unhos',
  'venda do pinheiro', 'ventosa', 'vialonga', 'vila franca de xira', 'vila verde dos francos', 'vimeiro');
update public.places set district = 'Portalegre' where key in (
  'alagoa', 'alegrete', 'alter do chao', 'arronches', 'atalaia', 'avis',
  'campo maior', 'cano', 'castelo de vide', 'crato', 'elvas', 'fortios',
  'fronteira', 'gaviao', 'marvao', 'monforte', 'montargil', 'nisa',
  'ponte de sor', 'portalegre', 'povoa e meadas', 'reguengo', 'sao juliao', 'sousel',
  'urra', 'vale da amoreira');
update public.places set district = 'Porto' where key in (
  'afurada de baixo', 'agua longa', 'aguas santas', 'agucadoura', 'aldoar', 'alfena',
  'alpendurada', 'alto da maia', 'amarante', 'ameal', 'amorim', 'angeiras',
  'anta', 'arcozelo', 'argivai', 'arvore', 'aver o mar', 'aves',
  'avintes', 'azenha', 'azevedo', 'baguim do monte', 'baiao', 'bairro silva braga',
  'balazar', 'baltar', 'barrosas', 'beiriz de baixo', 'bela vista', 'bomfim',
  'bonjoia', 'bougado', 'campanha', 'campinas', 'canelas', 'canidelo',
  'carvalhosa', 'casteloes de cepeda', 'contumil', 'coronado', 'corujeira', 'crestuma',
  'cruz', 'ermesinde', 'estela', 'falcao', 'fanzeres', 'felgueiras',
  'ferreira', 'figueiro', 'foz do douro', 'foz do sousa', 'francos', 'frazao',
  'freamunde', 'gemunde', 'gondomar', 'granja', 'grijo', 'gueifaes',
  'guifoes', 'gulpilhares', 'jovim', 'lavra', 'leca da palmeira', 'leca do bailio',
  'lever', 'lordelo', 'lordelo do ouro', 'lousada', 'lustosa', 'macieira da maia',
  'maia', 'marco de canaveses', 'marco de canavezes', 'margaride', 'massarelos', 'matosinhos',
  'meinedo', 'melres', 'milheiros', 'mindelo', 'miramar', 'negrelos',
  'neiral', 'nevogilde', 'noeda', 'nogueira', 'oliveira do douro', 'pacos',
  'pacos de ferreira', 'paranhos', 'paredes', 'pedras rubras', 'pedroso', 'pedroucos',
  'penafiel', 'perafita', 'pereiro', 'perozinho', 'pinheiro manso', 'porto',
  'povoa de varzim', 'ramalde do meio', 'rebordoes', 'rebordosa', 'recarei', 'rio tinto',
  'sandim', 'santa cruz do bispo', 'santa maria de avioso', 'santo izidoro', 'santo ovidio', 'santo tirso',
  'sao felix da marinha', 'sao mamede de infesta', 'sao miguel do couto', 'sao pedro da cova', 'sao tiago de custoias', 'sardao',
  'seixezelo', 'senhora da hora', 'senhora do porto', 'sermonde', 'seroa', 'silva escura',
  'sobrado', 'teloes', 'trofa', 'vairao', 'valbom', 'valongo',
  'vermoim', 'vila da lixa', 'vila do conde', 'vila mea', 'vila nova da telha', 'vila nova de gaia',
  'vilar de andorinho', 'vilar do paraiso', 'vilarinho');
update public.places set district = 'Santarém' where key in (
  'abrantes', 'alcanede', 'alcanena', 'alcanhoes', 'alferrarede', 'almeirim',
  'alpiarca', 'amiaes de baixo', 'bemfica', 'benavente', 'cartaxo', 'chamusca',
  'constancia', 'coruche', 'entroncamento', 'fatima', 'fazendas de almeirim', 'ferreira do zezere',
  'golega', 'macao', 'marinhais', 'meia via', 'minde', 'monsanto',
  'montalvinho', 'montalvo', 'ourem', 'paialvo', 'pego', 'pinheiro grande',
  'poceirao', 'pontevel', 'praia do ribatejo', 'riachos', 'rio maior', 'salvaterra de magos',
  'samora correia', 'santa margarida da coutada', 'santarem', 'sao miguel de rio torto', 'sao vicente do paul', 'sardoal',
  'tomar', 'torres novas', 'tramagal', 'vale de figueira', 'vale de santarem', 'vila cha de ourique',
  'vila nova da barquinha', 'zibreira');
update public.places set district = 'Setúbal' where key in (
  'alcacer do sal', 'alcochete', 'aldeia de paio pires', 'alhos vedros', 'almada', 'amora',
  'arrentela', 'azeitao', 'barreiro', 'cacilhas', 'caparica', 'cercal',
  'charneca de caparica', 'comporta', 'corroios', 'costa da caparica', 'costa de caparica', 'ermidas',
  'grandola', 'lavradio', 'moita', 'montijo', 'palmela', 'piedade',
  'pinhal novo', 'porto covo', 'pragal', 'quinta de santo antonio', 'quinta do anjo', 'quinta do conde',
  'rosairinho', 'samouco', 'santiago do cacem', 'santo antonio da charneca', 'sarilhos pequenos', 'seixal',
  'sesimbra', 'setubal', 'sines', 'sobreda', 'trafaria');
update public.places set district = 'Viana do Castelo' where key in (
  'arcos de valdevez', 'caminha', 'darque', 'meadela', 'melgaco', 'moncao',
  'mozelos', 'paredes de coura', 'ponte da barca', 'ponte de lima', 'valenca', 'valenza',
  'viana do castelo', 'vila', 'vila nova de cerveira', 'vila praia de ancora');
update public.places set district = 'Vila Real' where key in (
  'alijo', 'boticas', 'chaves', 'favaios', 'mesao frio', 'mondim de basto',
  'montalegre', 'murca', 'peso da regua', 'ribeira de pena', 'sabrosa', 'santa marta de penaguiao',
  'sobreira', 'valpacos', 'vidago', 'vila pouca de aguiar', 'vila real', 'vilela');
update public.places set district = 'Viseu' where key in (
  'abraveses', 'armamar', 'cabanas de viriato', 'campo de besteiros', 'canas de senhorim', 'carregal do sal',
  'castro daire', 'cinfaes', 'ervedosa do douro', 'lamego', 'mangualde', 'moimenta da beira',
  'mortagua', 'nelas', 'oliveira de frades', 'penalva do castelo', 'penedono', 'resende',
  'rio de loba', 'santa comba dao', 'sao joao da pesqueira', 'sao joao de areias', 'sao pedro do sul', 'satao',
  'sernancelhe', 'tabuaco', 'tarouca', 'tondela', 'treixedo', 'vila nova de paiva',
  'viseu', 'vouzela');
update public.places set district = 'Açores' where key in (
  'acores', 'agua de pau', 'angra do heroismo', 'angustias', 'arrifes', 'azores',
  'biscoitos', 'cabouco', 'cais do pico', 'calheta de sao jorge', 'corvo', 'faja de baixo',
  'fenais da ajuda', 'fenais da luz', 'feteira', 'fonte bastardo', 'furnas', 'horta',
  'ilha de sao miguel', 'lagoa', 'lajes das flores', 'lajes do pico', 'madalena', 'mosteiros',
  'nordeste', 'ponta delgada', 'ponta garca', 'porto judeu', 'porto martins', 'povoacao',
  'praia da vitoria', 'rabo de peixe', 'regiao autonoma dos acores', 'relva', 'ribeira grande', 'ribeirinha',
  'rosto de cao', 'santa barbara', 'santa cruz da graciosa', 'santa cruz das flores', 'sao mateus', 'sao roque do pico',
  'sao sebastiao', 'velas', 'vila do porto', 'vila franca do campo');
update public.places set district = 'Madeira' where key in (
  'agua de pena', 'arco da calheta', 'boaventura', 'calheta', 'camara de lobos', 'campanario',
  'canhas', 'canical', 'canico', 'corujeira de dentro', 'curral das freiras', 'estreito da calheta',
  'estreito de camara de lobos', 'faial', 'faja da ovelha', 'funchal', 'ilha da madeira', 'machico',
  'madeira', 'nossa senhora do monte', 'ponta do sol', 'porto da cruz', 'porto moniz', 'porto santo',
  'regiao autonoma da madeira', 'ribeira brava', 'santa cruz', 'santa maria maior', 'santana', 'santo antonio',
  'sao goncalo', 'sao jorge', 'sao martinho', 'sao vicente', 'vila baleira');

-- Every place has one now. places is a small read-only list (a few
-- thousand rows) that nothing on main writes, so the scan is harmless.
-- squawk-ignore adding-not-nullable-field
alter table public.places alter column district set not null;

-- The district of a place name (a listing's location); null when unknown.
create function public.place_district(p_location text)
returns text
language sql
stable
set search_path = ''
as $$
  select p.district from public.places p
  where p.key = public.place_key(p_location)
$$;

-- Computed field (listings.district): select and filter by it.
create function public.district(l public.listings)
returns text
language sql
stable
set search_path = ''
as $$
  select public.place_district(l.location)
$$;

grant execute on function public.district_names() to anon, authenticated;
grant execute on function public.place_district(text) to anon, authenticated;
grant execute on function public.district(public.listings) to anon, authenticated;

alter table public.saved_searches
  add column district  text check (district = any (public.district_names())),
  add column max_year  smallint check (max_year between 1900 and 2100),
  add column min_price numeric(10,2) check (min_price >= 0);

-- A saved search's old free text becomes the district of that place when
-- it is one; text naming no known place is dropped (it matched loosely).
update public.saved_searches
set district = public.place_district(location),
    location = null
where location is not null;

-- A maximum year never matches a listing without one; a minimum price
-- never matches a placeholder price (under 300 €, no price), as the
-- maximum doesn't.
create or replace view public.saved_search_matches
with (security_invoker = true) as
select s.id as saved_search_id, l.id as listing_id
from public.saved_searches s
join public.listings l
  on l.status in ('active', 'price_changed')
 and l.duplicate_of is null
 and public.listing_matches_search(
       l.motorcycle_id, l.year, l.price, l.mileage, l.location, l.seller_type,
       null, s.min_year, s.max_price, s.max_mileage, s.location,
       s.seller_type
     )
 and (cardinality(s.motorcycle_ids) = 0 or l.motorcycle_id = any (s.motorcycle_ids))
 and public.owner_tracks(s.user_id, l.motorcycle_id, l.year)
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras))
 and (not s.only_my_colours
      or public.likes_colour(s.user_id, l.motorcycle_id, l.colour))
 and (s.district is null or public.place_district(l.location) = s.district)
 and (s.max_year is null or l.year <= s.max_year)
 and (s.min_price is null or (l.price >= 300 and l.price >= s.min_price));
