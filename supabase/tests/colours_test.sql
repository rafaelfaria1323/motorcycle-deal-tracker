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

insert into public.listings (source, source_listing_id, url, brand, model, price, variant, description)
values ('standvirtual', 'col-1', 'https://x/1', 'Yamaha', 'MT-07', 6000, 'MT-07', 'Cor: azul'),
       ('olx', 'col-2', 'https://x/2', 'Yamaha', 'MT-07', 6000, 'MT-07 preta', null),
       ('olx', 'col-3', 'https://x/3', 'Yamaha', 'MT-07', 6000, 'MT-07', 'Sem cor dita');

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
end $$;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';

do $$
begin
  assert not (select public.my_colour(l) from public.listings l
              where source_listing_id = 'col-2'), 'no colours chosen: no mark';
end $$;

insert into public.user_colours (colours) values ('{black,red}');

do $$
declare
  v_scores int[];
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.listings l where public.my_colour(l))
         = array['col-1', 'col-2'];
  assert not (select public.my_colour(l) from public.listings l
              where source_listing_id = 'col-3'), 'unknown colour: no mark';
  begin
    insert into public.user_colours (colours) values ('{teal}');
    raise exception 'an unknown colour code was saved';
  exception when check_violation or unique_violation then null;
  end;
end $$;

-- Each account's colours are its own.
set local test.uid = '00000000-0000-0000-0000-0000000000c2';
do $$
begin
  assert (select count(*) from public.user_colours) = 0;
  assert not exists (select 1 from public.listings l where public.my_colour(l));
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
