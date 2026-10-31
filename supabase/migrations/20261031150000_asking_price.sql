-- F.2: an asking price under 300 € is a placeholder ("1 €", "consulte"),
-- which the scores and estimates leave out already. The computed field
-- listings.asking_price is the price without placeholders (null for
-- them), so Ofertas' price sorts put them last (PostgREST orders by it,
-- nulls last) and its maximum price no longer matches them. A saved
-- search's maximum price does the same: a placeholder ad doesn't alert
-- "up to 8 000 €".

create function public.asking_price(l public.listings)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when l.price >= 300 then l.price end
$$;

grant execute on function public.asking_price(public.listings) to anon, authenticated;

create or replace function public.listing_matches_search(
  l_motorcycle_id uuid,
  l_year          integer,
  l_price         numeric,
  l_mileage       integer,
  l_location      text,
  l_seller_type   public.seller_type,
  s_motorcycle_id uuid,
  s_min_year      integer,
  s_max_price     numeric,
  s_max_mileage   integer,
  s_location      text,
  s_seller_type   public.seller_type
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (s_motorcycle_id is null or l_motorcycle_id = s_motorcycle_id)
    and (s_min_year is null or l_year >= s_min_year)
    and (s_max_price is null or (l_price >= 300 and l_price <= s_max_price))
    and (s_max_mileage is null or l_mileage <= s_max_mileage)
    and (s_location is null
         or strpos(lower(coalesce(l_location, '')), lower(s_location)) > 0)
    and (s_seller_type is null or l_seller_type = s_seller_type),
    false
  )
$$;
