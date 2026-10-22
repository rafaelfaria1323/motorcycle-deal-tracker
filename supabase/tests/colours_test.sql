-- Bike colours: read from the site's field, the variant or "cor" in the
-- description; each account's favourite colours mark listings, never the
-- score.
do $$
begin
  assert public.colour_code('Preto') = 'black';
  assert public.colour_code('Cinzento metalizado') = 'grey';
  assert public.colour_code('Icon Blue') = 'blue';
  assert public.colour_code('Grand Prix Red') = 'red';
  assert public.colour_code('blue') = 'blue', 'the site''s ids';
  assert public.colour_code('Tech Kamo') is null;
  assert public.colour_code(null) is null;

  assert public.colour_in_text('MT-07 Pure Preta', null) = 'black';
  assert public.colour_in_text('MT-07 com escape preto', null) is null,
    'after "com" come the extras';
  assert public.colour_in_text(null, 'Mota em bom estado. Cor: azul.') = 'blue';
  assert public.colour_in_text(null, 'Vendo moto de cor branca') = 'white';
  assert public.colour_in_text(null, 'cor de laranja, impecável') = 'orange';
  assert public.colour_in_text(null, 'Pintura na cor original, cor cinzento') = 'grey',
    'a "cor" with no colour after it is skipped';
  assert public.colour_in_text(null, 'Escape preto e punhos aquecidos') is null,
    'a colour without "cor" in the description is a part''s';
  assert public.colour_in_text('CB650R Vermelha', 'Cor: preta') = 'red',
    'the variant first';
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1'),
                                   ('00000000-0000-0000-0000-0000000000c2');
-- Both accounts follow every collected model.
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year from auth.users u cross join public.motorcycles m
where m.is_active;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, variant, description)
select v.src, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 6000, v.variant, v.descr
from public.motorcycles m,
     (values ('standvirtual', 'col-1', 'MT-07', 'Cor: azul'),
             ('olx', 'col-2', 'MT-07 preta', null),
             ('olx', 'col-3', 'MT-07', 'Sem cor dita')) v(src, sid, variant, descr)
where m.slug = 'yamaha-mt-07';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, variant)
select 'olx', 'col-4', 'https://x/col-4', m.id, m.brand, m.model, 6000, 'CBR650R azul'
from public.motorcycles m
where m.slug = 'honda-cbr650r';

do $$
begin
  assert (select colour from public.listings where source_listing_id = 'col-1') = 'blue';
  assert (select colour from public.listings where source_listing_id = 'col-2') = 'black';
  assert (select colour from public.listings where source_listing_id = 'col-3') is null;

  -- The site's field wins over the text.
  perform public.apply_listing_details('standvirtual',
    '[{"source_listing_id": "col-1", "site_colour": "red"}]');
  assert (select (site_colour, colour) = ('red', 'red')
          from public.listings where source_listing_id = 'col-1');
  -- A later read without the field keeps it.
  perform public.apply_listing_details('standvirtual',
    '[{"source_listing_id": "col-1", "description": "Cor: verde"}]');
  assert (select colour from public.listings where source_listing_id = 'col-1') = 'red';
  perform public.apply_listing_details('standvirtual',
    '[{"source_listing_id": "col-1", "site_colour": "blue"}]');
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';

do $$
begin
  assert not exists (select 1 from public.listings l where public.my_colour(l)),
    'no colours chosen: no mark';
end $$;

-- Blue for the MT-07, black for the CBR650R.
select public.set_model_colours(m.id, '{blue}') from public.motorcycles m
where m.slug = 'yamaha-mt-07';
select public.set_model_colours(m.id, '{black}') from public.motorcycles m
where m.slug = 'honda-cbr650r';
insert into public.saved_searches (name, only_my_colours) values ('Cores', true),
                                                                 ('Todas', false);

do $$
declare
  refused boolean := false;
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.listings l where public.my_colour(l)) = array['col-1'],
    'a colour counts only for its model';
  assert (select public.my_colours(m) from public.motorcycles m
          where m.slug = 'yamaha-mt-07') = '{blue}';
  assert (select public.my_colours(m) from public.motorcycles m
          where m.slug = 'yamaha-r7') = '{}';
  -- Choosing colours doesn't change what the account follows.
  assert (select bool_and(u.tracked) from public.user_models u);

  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches sm
          join public.saved_searches s on s.id = sm.saved_search_id
          join public.listings l on l.id = sm.listing_id
          where s.name = 'Cores') = array['col-1'], 'only my colours';
  assert (select count(*)
          from public.saved_search_matches sm
          join public.saved_searches s on s.id = sm.saved_search_id
          where s.name = 'Todas') = 4;

  begin
    perform public.set_model_colours(m.id, '{teal}') from public.motorcycles m
    where m.slug = 'yamaha-mt-07';
  exception when check_violation then refused := true;
  end;
  assert refused, 'an unknown colour code is refused';
end $$;

reset role;

-- The alerts say when the bike is in the person's colour.
insert into public.alerts (user_id, listing_id, type)
select '00000000-0000-0000-0000-0000000000c1', l.id, 'new_listing'
from public.listings l where l.source_listing_id in ('col-1', 'col-4');
do $$
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.pending_notifications() p
          join public.listings l on l.id = p.listing_id
          where p.my_colour) = array['col-1'];
  assert (select count(*) from public.pending_notifications()) = 2;
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';

-- A model not followed keeps its colours, still not followed.
select public.set_model_colours(m.id, '{red}') from public.motorcycles m
where not m.is_active limit 1;
do $$
begin
  assert (select not u.tracked and u.colours = '{red}'
          from public.user_models u join public.motorcycles m on m.id = u.motorcycle_id
          where not m.is_active);
end $$;

-- Each account's colours are its own.
set local test.uid = '00000000-0000-0000-0000-0000000000c2';
do $$
begin
  assert not exists (select 1 from public.listings l where public.my_colour(l));
  assert (select public.my_colours(m) from public.motorcycles m
          where m.slug = 'yamaha-mt-07') = '{}';
end $$;

-- Anonymous sessions can't choose colours.
set local test.jwt = '{"is_anonymous": true}';
do $$
declare
  refused boolean := false;
begin
  begin
    perform public.set_model_colours(m.id, '{blue}') from public.motorcycles m
    where m.slug = 'yamaha-mt-07';
  exception when others then refused := true;
  end;
  assert refused;
end $$;
reset role;

-- The score doesn't change with colour.
do $$
begin
  assert not exists (
    select 1 from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname like '%score%'
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) ilike '%colour%');
end $$;
