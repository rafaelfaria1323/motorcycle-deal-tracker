-- "Quanto vale a minha mota" (16.9): the estimate of a bike that isn't
-- listed, from the same comparables and rules as a listing's fair price
-- (listing_fair_prices): the model's live, non-duplicate ads of 300 € or
-- more, only those within 3 years when there are at least 5 of them, each
-- brought to the bike's year and mileage with the model's own depreciation
-- rates. Without a mileage, comparables of any mileage count and it isn't
-- adjusted; with one, comparables without mileage are left out (likewise
-- the year).
--
-- Also the middle half of those adjusted prices (25th to 75th percentile),
-- so the app can say where most of them sit. Reads only what everyone can
-- read already: security invoker.
create function public.bike_value(
  p_motorcycle_id uuid,
  p_year          integer,
  p_mileage       integer default null
)
returns table (
  comparable_count integer,
  fair_price       numeric,
  low_price        numeric,
  high_price       numeric
)
language sql
stable
set search_path = ''
as $$
  with comparables as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near
    from public.listings c
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('active', 'price_changed')
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
  ),
  chosen as (
    select c.*
    from comparables c
    where c.near
       or (select count(*) from comparables n where n.near) < 5
  ),
  adjusted as (
    select ch.price * public.age_mileage_factor(
             p_year - ch.year,
             p_mileage - ch.mileage,
             coalesce(d.per_year, 0.04),
             coalesce(d.per_1000km, 0.002)
           ) as price
    from chosen ch
    left join public.model_depreciation d on d.motorcycle_id = p_motorcycle_id
  )
  select
    count(*)::integer,
    round((percentile_cont(0.5)  within group (order by price))::numeric, 2),
    round((percentile_cont(0.25) within group (order by price))::numeric, 2),
    round((percentile_cont(0.75) within group (order by price))::numeric, 2)
  from adjusted;
$$;

revoke all on function public.bike_value(uuid, integer, integer) from public;
grant execute on function public.bike_value(uuid, integer, integer) to anon, authenticated;
