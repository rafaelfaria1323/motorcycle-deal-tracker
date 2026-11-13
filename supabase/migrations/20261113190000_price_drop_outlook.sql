-- Waiting or buying now (N.83): what happened to the model's other ads in
-- the days after they were as old as this one. Each other ad (not a
-- duplicate, not this ad or the one it repeats) counts when it was still
-- for sale at this ad's age and was followed for the whole window after
-- it (gone before its end, or seen for that long). Within the window it
-- either dropped its price by 1 % or more (to a real price: 300 € or more),
-- else left the market, else stayed as it was. Ages count from when each
-- ad was first seen, since price history starts there. Only for a live ad
-- with a real price; the app shows it from 5 ads. Never part of a score.
-- Security invoker: listings and their prices are readable by everyone.
create or replace function public.price_drop_outlook(
  p_listing_id uuid,
  p_days integer default 30
)
returns table (
  sample integer,
  dropped integer,
  gone integer,
  unchanged integer,
  median_drop numeric
)
language sql
stable
set search_path = ''
as $$
  with me as (
    select l.id, l.motorcycle_id, l.duplicate_of,
           greatest(interval '0', now() - l.first_seen_at) as age
    from public.listings l
    where l.id = p_listing_id
      and l.motorcycle_id is not null
      and l.status in ('active', 'price_changed')
      and l.price >= 300
  ),
  windows as (
    select o.id,
           o.status in ('removed', 'sold') as is_gone,
           case when o.status in ('removed', 'sold') then o.last_seen_at
                else now() end as ended,
           o.first_seen_at + me.age as starts,
           o.first_seen_at + me.age + make_interval(days => p_days) as ends
    from me
    join public.listings o on o.motorcycle_id = me.motorcycle_id
    where o.duplicate_of is null
      and o.id <> me.id
      and o.id is distinct from me.duplicate_of
  ),
  followed as (
    select w.*,
           (select h.price
            from public.listing_price_history h
            where h.listing_id = w.id and h.observed_at <= w.starts
            order by h.observed_at desc
            limit 1) as start_price
    from windows w
    where w.ended >= w.starts
      and (w.is_gone or now() >= w.ends)
  ),
  outcomes as (
    select f.start_price,
           f.is_gone and f.ended <= f.ends as left_market,
           (select min(h.price)
            from public.listing_price_history h
            where h.listing_id = f.id
              and h.observed_at > f.starts
              and h.observed_at <= f.ends
              and h.price >= 300
              and h.price <= f.start_price * 0.99) as low
    from followed f
    where f.start_price >= 300
  )
  select count(*)::integer,
         count(*) filter (where o.low is not null)::integer,
         count(*) filter (where o.low is null and o.left_market)::integer,
         count(*) filter (where o.low is null and not o.left_market)::integer,
         round((percentile_cont(0.5) within group (
           order by (1 - o.low / o.start_price) * 100)
           filter (where o.low is not null))::numeric, 1)
  from outcomes o
  where exists (select 1 from me)
$$;

revoke all on function public.price_drop_outlook(uuid, integer) from public;
grant execute on function public.price_drop_outlook(uuid, integer)
  to anon, authenticated;
