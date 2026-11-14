-- N.106b: when a model has too few gone ads for the time-on-market
-- figures, its similar models' ads stand in (the same engine and frame in
-- another body: an MT-07 sells like an R7 or a Tracer 7). Only the time on
-- the market and the price drops: prices differ between them, so the fair
-- value, the bike value and the exit prices stay the model's own.
--   motorcycles.similar_group   the models that share a platform (null:
--                               none; seeded below, by brand and name)
--   similar_motorcycle_ids()    the model and the others of its group
--   model_market_behaviour      + similar_gone_count,
--                               similar_median_days_to_gone, similar_models
--                               (the group's figures; the app takes them
--                               when the model's own gone ads are under 5)
--   listing_time_to_sale        + similar_models: the group's ads when the
--   price_drop_outlook          model's own gave fewer than 5 (gone ads /
--                               ads followed) and the group gives more
-- Shown with the names of the other models used. Never a score.

alter table public.motorcycles
  add column if not exists similar_group text;

-- The platforms, by brand and the letters and digits of the name, so
-- models added from the app under those names join too.
update public.motorcycles m
set similar_group = v.grp
from (values
  ('yamaha', 'mt07',       'yamaha-cp2'),
  ('yamaha', 'r7',         'yamaha-cp2'),
  ('yamaha', 'yzfr7',      'yamaha-cp2'),
  ('yamaha', 'tracer7',    'yamaha-cp2'),
  ('yamaha', 'tracer700',  'yamaha-cp2'),
  ('yamaha', 'xsr700',     'yamaha-cp2'),
  ('yamaha', 'mt09',       'yamaha-cp3'),
  ('yamaha', 'r9',         'yamaha-cp3'),
  ('yamaha', 'yzfr9',      'yamaha-cp3'),
  ('yamaha', 'tracer9',    'yamaha-cp3'),
  ('yamaha', 'tracer9gt',  'yamaha-cp3'),
  ('yamaha', 'xsr900',     'yamaha-cp3'),
  ('yamaha', 'mt03',       'yamaha-321'),
  ('yamaha', 'r3',         'yamaha-321'),
  ('yamaha', 'yzfr3',      'yamaha-321'),
  ('honda',  'cb650r',     'honda-650-four'),
  ('honda',  'cbr650r',    'honda-650-four'),
  ('honda',  'cb650f',     'honda-650-four'),
  ('honda',  'cbr650f',    'honda-650-four'),
  ('honda',  'cbr500r',    'honda-500-twin'),
  ('honda',  'cb500f',     'honda-500-twin'),
  ('honda',  'cb500x',     'honda-500-twin'),
  ('honda',  'cb500hornet','honda-500-twin'),
  ('honda',  'nx500',      'honda-500-twin')
) as v(brand_key, model_key, grp)
where public.name_key(m.brand) = v.brand_key
  and public.name_key(m.model) = v.model_key
  and m.similar_group is distinct from v.grp;

-- The model first, then the others of its group.
create or replace function public.similar_motorcycle_ids(p_motorcycle_id uuid)
returns uuid[]
language sql stable
set search_path = ''
as $$
  select array[p_motorcycle_id] || coalesce((
    select array_agg(o.id order by o.model, o.id)
    from public.motorcycles me
    join public.motorcycles o
      on o.similar_group = me.similar_group and o.id <> me.id
    where me.id = p_motorcycle_id
  ), '{}')
$$;
revoke all on function public.similar_motorcycle_ids(uuid) from public;
grant execute on function public.similar_motorcycle_ids(uuid)
  to anon, authenticated, service_role;

-- Same columns as before, then the group's.
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
),
own as (
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
  group by motorcycle_id
),
grouped as (
  select
    m.similar_group,
    count(*) filter (where b.gone)                                 as gone_count,
    round(public.median_days_remaining(
        array_agg(b.days) filter (where b.gone or b.status in ('active', 'price_changed')),
        array_agg(b.gone) filter (where b.gone or b.status in ('active', 'price_changed')),
        0))                                                        as median_days_to_gone,
    array_agg(distinct b.motorcycle_id)                            as ids
  from base b
  join public.motorcycles m on m.id = b.motorcycle_id
  where m.similar_group is not null
  group by m.similar_group
)
select
  o.motorcycle_id,
  o.live_count,
  o.gone_count,
  o.median_days_to_gone,
  o.median_days_listed_live,
  o.priced_count,
  o.dropped_count,
  o.median_drop_pct,
  -- The group's, only when another model of it has ads.
  case when s.names is not null then g.gone_count end              as similar_gone_count,
  case when s.names is not null then g.median_days_to_gone end     as similar_median_days_to_gone,
  coalesce(s.names, '{}')                                          as similar_models
from own o
join public.motorcycles m on m.id = o.motorcycle_id
left join grouped g on g.similar_group = m.similar_group
left join lateral (
  select array_agg(m2.model order by m2.model) as names
  from public.motorcycles m2
  where m2.id = any(g.ids) and m2.id <> o.motorcycle_id
) s on true;

-- The return types gain a column: dropped and made again, with the grants.
drop function public.listing_time_to_sale(uuid);
create function public.listing_time_to_sale(p_listing_id uuid)
returns table(band text, gone_count integer, live_count integer,
              days_listed integer, typical_days integer,
              remaining_days integer, similar_models text[])
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
  models uuid[];
  group_gone integer;
begin
  select * into l from public.listings where id = p_listing_id;
  if l.id is null or l.motorcycle_id is null then
    return;
  end if;

  age := greatest(0, extract(epoch from
           now() - coalesce(l.published_at, l.first_seen_at)) / 86400);
  my_band := public.market_band(l.last_pct_below_market);
  models := array[l.motorcycle_id];
  similar_models := '{}';

  -- The model's own gone ads first; under 5, its group's when they are
  -- more (N.106b). A gone ad one run saw tells nothing (N.93).
  for attempt in 1..2 loop
    with sample as (
      select greatest(0, extract(epoch from
               case when o.status in ('removed', 'sold') then o.last_seen_at
                    else now() end
               - coalesce(o.published_at, o.first_seen_at)) / 86400) as days,
             o.status in ('removed', 'sold') as gone,
             public.market_band(o.last_pct_below_market) as band
      from public.listings o
      where o.motorcycle_id = any(models)
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

    gone_count := coalesce(gone_count, 0);
    exit when attempt = 2 or gone_count >= 5;

    -- Would the group give more?
    select count(*) into group_gone
    from public.listings o
    where o.motorcycle_id = any(public.similar_motorcycle_ids(l.motorcycle_id))
      and o.motorcycle_id <> l.motorcycle_id
      and o.duplicate_of is null
      and o.status in ('removed', 'sold')
      and o.last_seen_at - o.first_seen_at >= interval '1 hour';
    exit when group_gone = 0;
    select array_agg(m.model order by m.model) into similar_models
    from public.motorcycles m
    where m.id = any(public.similar_motorcycle_ids(l.motorcycle_id))
      and m.id <> l.motorcycle_id
      and exists (select 1 from public.listings o
                  where o.motorcycle_id = m.id
                    and o.duplicate_of is null
                    and o.status in ('removed', 'sold')
                    and o.last_seen_at - o.first_seen_at >= interval '1 hour');
    models := public.similar_motorcycle_ids(l.motorcycle_id);
  end loop;

  band := case when use_band then my_band end;
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
revoke all on function public.listing_time_to_sale(uuid) from public;
grant execute on function public.listing_time_to_sale(uuid)
  to anon, authenticated, service_role;

-- What the ads of these models did after they were as old as this one;
-- the body of price_drop_outlook, for one set of models.
create or replace function public.price_drop_outlook_among(
  p_listing_id uuid, p_days integer, p_models uuid[])
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
    join public.listings o on o.motorcycle_id = any(p_models)
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
revoke all on function public.price_drop_outlook_among(uuid, integer, uuid[]) from public;
grant execute on function public.price_drop_outlook_among(uuid, integer, uuid[])
  to anon, authenticated, service_role;

drop function public.price_drop_outlook(uuid, integer);
create function public.price_drop_outlook(
  p_listing_id uuid, p_days integer default 30)
returns table(sample integer, dropped integer, gone integer,
              unchanged integer, median_drop numeric, similar_models text[])
language plpgsql stable
set search_path = ''
as $$
declare
  v_model uuid := (select l.motorcycle_id from public.listings l
                   where l.id = p_listing_id);
  v_group uuid[];
  v_own integer;
  o record;
  g record;
begin
  if v_model is null then
    return;
  end if;
  select * into o
  from public.price_drop_outlook_among(p_listing_id, p_days, array[v_model]);
  v_own := coalesce(o.sample, 0);
  similar_models := '{}';

  -- Under 5 ads followed: the group's, when they are more (N.106b).
  v_group := public.similar_motorcycle_ids(v_model);
  if v_own < 5 and cardinality(v_group) > 1 then
    select * into g
    from public.price_drop_outlook_among(p_listing_id, p_days, v_group);
    if g.sample > v_own then
      o := g;
      -- The other models whose ads were followed.
      select coalesce(array_agg(m.model order by m.model), '{}')
      into similar_models
      from public.motorcycles m
      where m.id = any(v_group) and m.id <> v_model
        and (select s.sample
             from public.price_drop_outlook_among(p_listing_id, p_days,
                                                  array[v_model, m.id]) s)
            > v_own;
    end if;
  end if;

  sample := o.sample;
  dropped := o.dropped;
  gone := o.gone;
  unchanged := o.unchanged;
  median_drop := o.median_drop;
  return next;
end;
$$;
revoke all on function public.price_drop_outlook(uuid, integer) from public;
grant execute on function public.price_drop_outlook(uuid, integer)
  to anon, authenticated, service_role;
