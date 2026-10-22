-- Favourite colours. Each account can say which colours it likes; a
-- listing in one of them is shown as a plus, but the Deal Score never
-- counts it (an older bike or one with more km must not beat a better one
-- for its colour). listings.colour holds the bike's colour as a code:
-- Standvirtual's listing page has a colour field (site_colour), otherwise
-- the colour is read from the variant (Standvirtual's version, OLX's
-- title) or after "cor" in the description.

alter table public.listings
  add column site_colour text,
  add column colour text;

-- The first colour word in a text, as a code; null when there is none.
-- Portuguese (any gender or number), English and Italian words, as the
-- makers name their paints ("Icon Blue", "Rosso").
create function public.colour_code(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select c.code
  from regexp_split_to_table(
         translate(lower(coalesce(p_text, '')),
                   'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'),
         '[^a-z]+') with ordinality as w(word, n)
  join (values
    ('preto', 'black'), ('preta', 'black'), ('pretos', 'black'),
    ('pretas', 'black'), ('negro', 'black'), ('negra', 'black'),
    ('black', 'black'), ('nero', 'black'),
    ('branco', 'white'), ('branca', 'white'), ('brancos', 'white'),
    ('brancas', 'white'), ('white', 'white'), ('bianco', 'white'),
    ('cinzento', 'grey'), ('cinzenta', 'grey'), ('cinza', 'grey'),
    ('grafite', 'grey'), ('antracite', 'grey'), ('grey', 'grey'),
    ('gray', 'grey'),
    ('prateado', 'silver'), ('prateada', 'silver'), ('prata', 'silver'),
    ('silver', 'silver'),
    ('azul', 'blue'), ('azuis', 'blue'), ('blue', 'blue'),
    ('vermelho', 'red'), ('vermelha', 'red'), ('vermelhos', 'red'),
    ('vermelhas', 'red'), ('encarnado', 'red'), ('encarnada', 'red'),
    ('red', 'red'), ('rosso', 'red'),
    ('verde', 'green'), ('verdes', 'green'), ('green', 'green'),
    ('amarelo', 'yellow'), ('amarela', 'yellow'), ('yellow', 'yellow'),
    ('laranja', 'orange'), ('orange', 'orange'),
    ('castanho', 'brown'), ('castanha', 'brown'), ('brown', 'brown'),
    ('bege', 'beige'), ('beige', 'beige'),
    ('dourado', 'gold'), ('dourada', 'gold'), ('gold', 'gold'),
    ('roxo', 'purple'), ('roxa', 'purple'), ('violeta', 'purple'),
    ('lilas', 'purple'), ('purple', 'purple'), ('violet', 'purple'),
    ('rosa', 'pink'), ('pink', 'pink')
  ) as c(word, code) on c.word = w.word
  order by w.n
  limit 1
$$;

-- The colour an ad's text gives: a colour word in the variant (before
-- "com", which starts the extras: "MT-07 com escape preto"), else the word
-- after "cor" in the description ("Cor: preta", "de cor azul", "na cor
-- cinzento"; "cor original" says nothing).
create function public.colour_in_text(p_variant text, p_description text)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    public.colour_code(split_part(lower(coalesce(p_variant, '')), ' com ', 1)),
    (select public.colour_code(m[1])
     from regexp_matches(lower(coalesce(p_description, '')),
            '\m(?:cor|colou?r)\M\s*[:=-]?\s*(?:(?:é|e|de|da|do)\s+)?([[:alpha:]]+)',
            'g') with ordinality as x(m, n)
     where public.colour_code(m[1]) is not null
     order by n
     limit 1))
$$;

revoke all on function public.colour_code(text)
  from public, anon, authenticated;
revoke all on function public.colour_in_text(text, text)
  from public, anon, authenticated;

-- The site's field wins; the text only fills in.
create function public.fill_listing_colour()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.colour := coalesce(public.colour_code(new.site_colour),
                         public.colour_in_text(new.variant, new.description));
  return new;
end;
$$;

revoke all on function public.fill_listing_colour()
  from public, anon, authenticated;

create trigger listings_colour
  before insert or update of site_colour, variant, description on public.listings
  for each row execute function public.fill_listing_colour();

-- The listings already stored.
update public.listings
set colour = public.colour_in_text(variant, description)
where true;

-- Standvirtual's listing page brings the colour field too.
create or replace function public.apply_listing_details(p_source text, p_details jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set description            = coalesce(d.description, l.description),
      registrations          = coalesce(d.registrations, l.registrations),
      service_book           = coalesce(d.service_book, l.service_book),
      origin                 = coalesce(d.origin, l.origin),
      warranty_until         = coalesce(d.warranty_until, l.warranty_until),
      dealer_warranty_months = coalesce(d.dealer_warranty_months,
                                        l.dealer_warranty_months),
      published_at           = least(d.published_at, l.published_at),
      site_colour            = coalesce(d.site_colour, l.site_colour),
      -- A page without photos keeps the search's thumbnail.
      images                 = case when cardinality(d.images) > 0
                                    then d.images else l.images end,
      details_checked_at     = now(),
      photos_read_at         = now()
  from jsonb_to_recordset(p_details) as d(
    source_listing_id      text,
    description            text,
    registrations          smallint,
    service_book           boolean,
    origin                 text,
    warranty_until         date,
    dealer_warranty_months smallint,
    published_at           timestamptz,
    site_colour            text,
    images                 text[]
  )
  where l.source = p_source
    and l.source_listing_id = d.source_listing_id;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_listing_details(text, jsonb)
  from public, anon, authenticated;

-- Each account's favourite colours (codes, as listings.colour).
create table public.user_colours (
  user_id    uuid primary key default auth.uid()
               references auth.users (id) on delete cascade,
  colours    text[] not null default '{}'
               check (colours <@ array['black', 'white', 'grey', 'silver',
                 'blue', 'red', 'green', 'yellow', 'orange', 'brown',
                 'beige', 'gold', 'purple', 'pink']),
  updated_at timestamptz not null default now()
);

alter table public.user_colours enable row level security;

create policy "Users manage their own colours"
  on public.user_colours
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

grant insert, update, delete on public.user_colours to authenticated;

-- Computed field (listings.my_colour): the listing is in one of the
-- caller's favourite colours. Never part of the Deal Score.
create function public.my_colour(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select l.colour = any (c.colours)
     from public.user_colours c
     where c.user_id = (select auth.uid())),
    false)
$$;

grant execute on function public.my_colour(public.listings) to anon, authenticated;
