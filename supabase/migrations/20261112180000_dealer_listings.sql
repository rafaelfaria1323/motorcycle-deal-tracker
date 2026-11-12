-- A dealer's page (N.72): every ad of one dealer we have seen, on both
-- sites, the same ads `dealer_reliability` counts (name trimmed and
-- case-folded, repeats of another ad left out). Live ads first, newest
-- first, then the gone ones, last seen first. A set of listings, so the
-- app selects the same columns (computed fields included) as its lists.
-- Private sellers have no name stored, so they have no page.
create function public.dealer_listings(
  p_name text,
  p_limit integer default 100
)
returns setof public.listings
language sql
stable
set search_path = ''
as $$
  select l.*
  from public.listings l
  where l.seller_type = 'dealer'
    and lower(btrim(l.seller_name)) = lower(btrim(p_name))
    and nullif(btrim(p_name), '') is not null
    and l.duplicate_of is null
  order by l.status in ('active', 'price_changed') desc,
           case when l.status in ('active', 'price_changed')
                then l.first_seen_at else l.last_seen_at end desc,
           l.id
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

revoke all on function public.dealer_listings(text, integer)
  from public, anon, authenticated;
grant execute on function public.dealer_listings(text, integer)
  to anon, authenticated;

-- The page looks a dealer up by its key, as dealer_reliability groups.
create index listings_dealer_key
  on public.listings (lower(btrim(seller_name)))
  where seller_type = 'dealer';
