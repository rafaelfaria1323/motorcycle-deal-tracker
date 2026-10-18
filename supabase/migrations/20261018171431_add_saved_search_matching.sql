-- Does a listing satisfy a saved search? Empty criteria mean "any"; a set
-- criterion never matches an unknown value. Takes plain values so it can be
-- tested without rows.
create function public.listing_matches_search(
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
    and (s_max_price is null or l_price <= s_max_price)
    and (s_max_mileage is null or l_mileage <= s_max_mileage)
    and (s_location is null
         or strpos(lower(coalesce(l_location, '')), lower(s_location)) > 0)
    and (s_seller_type is null or l_seller_type = s_seller_type),
    false
  )
$$;

-- Every (saved search, live listing) pair that matches. Duplicates and
-- removed listings never match. Runs as the caller, so a person only sees
-- matches for their own searches.
create view public.saved_search_matches
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
     );

-- How many live listings each search matches (searches with none are absent).
create view public.saved_search_match_counts
with (security_invoker = true) as
select saved_search_id, count(*)::integer as match_count
from public.saved_search_matches
group by saved_search_id;

revoke all on public.saved_search_matches, public.saved_search_match_counts
  from public, anon;
grant select on public.saved_search_matches, public.saved_search_match_counts
  to authenticated;