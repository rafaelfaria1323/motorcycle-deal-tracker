-- F.11 (feature review 5.1): "Saíram do mercado por". The estimates
-- come only from asking prices; an ad that left the market without
-- coming back most likely sold, at or a little below its last price.
-- exit_price gives the median last price of a model's ads gone in the
-- last 90 days, each brought to the given year and mileage as
-- bike_value does (the same comparables within 3 years when 5 of them
-- are, the model's own rates). Shown in Mercado and with a bike's value
-- only; it feeds no score or fair value until it has been compared with
-- the estimate for some weeks.
--
-- Gone: removed or sold, last seen in the last 90 days, not a duplicate,
-- not relisted since (a later ad that is its relist means it didn't
-- sell), a real price (300 € or more). p_except leaves out a listing and
-- the one it repeats (the ad being looked at).

create function public.exit_price(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null,
  p_except uuid default null
)
returns table (gone_count integer, median_price numeric)
language sql
stable
set search_path = ''
as $$
  with excepted as (
    select e.id, e.duplicate_of
    from public.listings e
    where e.id = p_except
  ),
  gone as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near
    from public.listings c
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('removed', 'sold')
      and c.last_seen_at >= now() - interval '90 days'
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
      and not exists (
        select 1 from public.listings r where r.relisted_from = c.id
      )
      and not exists (
        select 1 from excepted x
        where c.id = x.id or c.id = x.duplicate_of
      )
  ),
  chosen as (
    select g.*
    from gone g
    where g.near
       or (select count(*) from gone n where n.near) < 5
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
    round((percentile_cont(0.5) within group (order by price))::numeric, 2)
  from adjusted;
$$;

revoke all on function public.exit_price(uuid, integer, integer, uuid)
  from public, anon, authenticated;
grant execute on function public.exit_price(uuid, integer, integer, uuid)
  to anon, authenticated, service_role;
