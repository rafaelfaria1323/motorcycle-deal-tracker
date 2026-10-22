-- Favourite colours. Each account can say which colours it likes for each
-- model ("blue" for the MT-07, "red" for the CBR650R); a listing in one of
-- them is shown as a plus and can be filtered and alerted on, but the Deal
-- Score never counts it (an older bike or one with more km must not beat a
-- better one for its colour). listings.colour holds the bike's colour as a code:
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

-- Each account's favourite colours per model ("blue" for the MT-07, "red"
-- for the CBR650R), codes as listings.colour.
alter table public.user_models
  add column colours text[] not null default '{}'
    check (colours <@ array['black', 'white', 'grey', 'silver', 'blue', 'red',
      'green', 'yellow', 'orange', 'brown', 'beige', 'gold', 'purple', 'pink']);

-- The caller's colours for a model (empty when none): the "Modelos
-- acompanhados" page.
create function public.my_colours(m public.motorcycles)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select u.colours from public.user_models u
     where u.user_id = (select auth.uid()) and u.motorcycle_id = m.id),
    '{}')
$$;

-- Whether the account likes this colour on this model. user_models is
-- read by its owner (RLS) and by the collector, so saved searches need no
-- security definer here.
create function public.likes_colour(p_user uuid, p_motorcycle_id uuid, p_colour text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.user_models u
                 where u.user_id = p_user
                   and u.motorcycle_id = p_motorcycle_id
                   and p_colour = any (u.colours))
$$;

-- Computed field (listings.my_colour): the listing is in one of the
-- caller's colours for its model. Never part of the Deal Score.
create function public.my_colour(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.likes_colour((select auth.uid()), l.motorcycle_id, l.colour)
$$;

grant execute on function public.my_colours(public.motorcycles) to anon, authenticated;
grant execute on function public.likes_colour(uuid, uuid, text) to anon, authenticated;
grant execute on function public.my_colour(public.listings) to anon, authenticated;

-- The caller's colours for a model; a model not followed keeps them for
-- when it is (as set_model_min_year).
create function public.set_model_colours(p_motorcycle_id uuid, p_colours text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  insert into public.user_models (user_id, motorcycle_id, tracked, min_year, colours)
  select auth.uid(), m.id, false, m.min_year, coalesce(p_colours, '{}')
  from public.motorcycles m where m.id = p_motorcycle_id
  on conflict (user_id, motorcycle_id)
  do update set colours = excluded.colours, updated_at = now();
end;
$$;

revoke all on function public.set_model_colours(uuid, text[]) from public, anon;
grant execute on function public.set_model_colours(uuid, text[]) to authenticated;

-- A saved search can ask only for the owner's colours of each model, so
-- its alerts say "a new one in your colour".
alter table public.saved_searches
  add column only_my_colours boolean not null default false;

create or replace view public.saved_search_matches
with (security_invoker = true) as
select s.id as saved_search_id, l.id as listing_id
from public.saved_searches s
join public.listings l
  on l.status in ('active', 'price_changed')
 and l.duplicate_of is null
 and public.listing_matches_search(
       l.motorcycle_id, l.year, l.price, l.mileage, l.location, l.seller_type,
       s.motorcycle_id, s.min_year, s.max_price, s.max_mileage, s.location,
       s.seller_type
     )
 and public.owner_tracks(s.user_id, l.motorcycle_id, l.year)
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras))
 and (not s.only_my_colours
      or public.likes_colour(s.user_id, l.motorcycle_id, l.colour));

-- An alert says when the bike is in the person's colour for its model
-- ("Novo anúncio na sua cor").
drop function public.pending_notifications(integer);

create function public.pending_notifications(p_limit integer default 200)
returns table (
  alert_id    uuid,
  user_id     uuid,
  listing_id  uuid,
  type        public.alert_type,
  old_price   numeric,
  new_price   numeric,
  brand       text,
  model       text,
  year        integer,
  mileage     integer,
  price       numeric,
  deal_score  smallint,
  location    text,
  url         text,
  to_telegram boolean,
  created_at  timestamptz,
  my_colour   boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.user_id, l.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text,
         exists (select 1 from public.app_admins ad where ad.user_id = a.user_id),
         a.created_at,
         public.likes_colour(a.user_id, l.motorcycle_id, l.colour)
  from public.alerts a
  join public.listings l on l.id = a.listing_id
  join auth.users u on u.id = a.user_id
  where a.notified_at is null
    and not coalesce(u.is_anonymous, false)
  order by a.created_at
  limit p_limit
$$;

revoke all on function public.pending_notifications(integer)
  from public, anon, authenticated;
