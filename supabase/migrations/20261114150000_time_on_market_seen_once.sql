-- N.93: the time-on-market figures leave out the gone ads only one run saw
-- (under an hour between first and last seen, exit_kind's `seen_once`,
-- N.92). Such an ad went before the next run looked: an ad the site showed
-- for a moment, or one read under a passing search, and its "0 days"
-- shortened the model's typical time (16 of the CB650R's gone ads). Live
-- ads stay, however new.
--   model_market_behaviour  the typical time (the offer, the seller's
--                           urgency), the gone count and the price drops
--   listing_time_to_sale    "Mercado deste modelo"
--   price_drop_outlook      "Esperar ou comprar já?"
-- Same columns, grants and security invoker as before.

create or replace view public.model_market_behaviour
with (security_invoker = true) as
with base as (
  select
    l.motorcycle_id,
    l.status,
    l.price,
    greatest(l.initial_price, l.price_before_drop) as initial_price,
    coalesce(l.published_at, l.first_seen_at) as listed_at,
    l.last_seen_at,
    l.status in ('removed', 'sold') as gone,
    greatest(0, extract(epoch from
      case when l.status in ('removed', 'sold') then l.last_seen_at
           else now() end
      - coalesce(l.published_at, l.first_seen_at)) / 86400) as days
  from public.listings l
  where l.motorcycle_id is not null
    and l.duplicate_of is null
    and not (l.status in ('removed', 'sold')
             and l.last_seen_at - l.first_seen_at < interval '1 hour')
)
select
  motorcycle_id,
  count(*) filter (where status in ('active', 'price_changed'))  as live_count,
  count(*) filter (where gone)                                   as gone_count,
  -- Kaplan-Meier: the ads still for sale count as lasting at least their age.
  round(public.median_days_remaining(
      array_agg(days) filter (where gone or status in ('active', 'price_changed')),
      array_agg(gone) filter (where gone or status in ('active', 'price_changed')),
      0))                                                        as median_days_to_gone,
  round((percentile_cont(0.5) within group (
      order by extract(epoch from now() - listed_at) / 86400)
    filter (where status in ('active', 'price_changed')))::numeric, 0)
                                                                 as median_days_listed_live,
  count(*) filter (where initial_price is not null)              as priced_count,
  count(*) filter (where initial_price is not null
                     and price < initial_price)                  as dropped_count,
  round((percentile_cont(0.5) within group (
      order by (initial_price - price) / initial_price * 100)
    filter (where initial_price is not null
              and price < initial_price))::numeric, 1)           as median_drop_pct
from base
group by motorcycle_id;

create or replace function public.listing_time_to_sale(p_listing_id uuid)
returns table(band text, gone_count integer, live_count integer,
              days_listed integer, typical_days integer,
              remaining_days integer)
language plpgsql stable
set search_path = ''
as $$
declare
  l public.listings;
  my_band text;
  age numeric;
  use_band boolean;
  days numeric[];
  gone boolean[];
begin
  select * into l from public.listings where id = p_listing_id;
  if l.id is null or l.motorcycle_id is null then
    return;
  end if;

  age := greatest(0, extract(epoch from
           now() - coalesce(l.published_at, l.first_seen_at)) / 86400);
  my_band := public.market_band(l.last_pct_below_market);

  -- A gone ad's band is where it was when last scored. A gone ad one run
  -- saw tells nothing of how long ads last (N.93).
  with sample as (
    select greatest(0, extract(epoch from
             case when o.status in ('removed', 'sold') then o.last_seen_at
                  else now() end
             - coalesce(o.published_at, o.first_seen_at)) / 86400) as days,
           o.status in ('removed', 'sold') as gone,
           public.market_band(o.last_pct_below_market) as band
    from public.listings o
    where o.motorcycle_id = l.motorcycle_id
      and o.duplicate_of is null
      and o.id <> l.id
      and o.id is distinct from l.duplicate_of
      and not (o.status in ('removed', 'sold')
               and o.last_seen_at - o.first_seen_at < interval '1 hour')
  ),
  chosen as (
    select s.*,
           my_band is not null
           and count(*) filter (where s.gone and s.band = my_band)
               over () >= 5 as by_band
    from sample s
  )
  select bool_or(c.by_band),
         array_agg(c.days), array_agg(c.gone),
         count(*) filter (where c.gone), count(*) filter (where not c.gone)
  into use_band, days, gone, gone_count, live_count
  from chosen c
  where not c.by_band or c.band = my_band;

  band := case when use_band then my_band end;
  gone_count := coalesce(gone_count, 0);
  live_count := coalesce(live_count, 0);
  days_listed := floor(age)::integer;
  if gone_count >= 5 then
    typical_days := ceil(public.median_days_remaining(days, gone, 0))::integer;
    if l.status in ('active', 'price_changed') then
      -- At least a day (greatest would also turn a null into 1).
      remaining_days := ceil(
        public.median_days_remaining(days, gone, age))::integer;
      if remaining_days < 1 then
        remaining_days := 1;
      end if;
    end if;
  end if;
  return next;
end;
$$;

create or replace function public.price_drop_outlook(
  p_listing_id uuid, p_days integer default 30)
returns table(sample integer, dropped integer, gone integer,
              unchanged integer, median_drop numeric)
language sql stable
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
      -- A gone ad one run saw (N.93).
      and not (o.status in ('removed', 'sold')
               and o.last_seen_at - o.first_seen_at < interval '1 hour')
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
