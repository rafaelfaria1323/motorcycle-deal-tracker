-- The score check's drop (N.61): the median drop over every likely sale
-- was 0.0 % for every model, since most never dropped. Now the likely
-- sales that dropped 1 % or more (the alerts' threshold) are counted,
-- and the median drop is of those only.
drop function public.score_check_models(integer);
create function public.score_check_models(p_days integer default 28)
returns table(
  model text,
  gone integer,
  sold_in_text integer,
  likely_sold integer,
  relisted integer,
  still_listed integer,
  expired integer,
  seen_once integer,
  sold_with_position integer,
  sold_position numeric,
  live_with_position integer,
  live_position numeric,
  sold_dropped integer,
  sold_drop_pct numeric,
  sold_days numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with gone as (
    select l.motorcycle_id,
           public.exit_kind(l) as kind,
           case when not coalesce(l.text_signals,
                                  public.description_signals(l.variant, l.description))
                     && array['possible_accident', 'needs_repair',
                              'not_legalised', 'not_legalised_outside_eu']
                then l.last_pct_below_market end as position,
           100 * (1 - l.price / nullif(greatest(l.initial_price, l.price_before_drop, l.price), 0))
             as drop_pct,
           extract(epoch from l.last_seen_at
                   - coalesce(l.published_at, l.first_seen_at)) / 86400 as days
    from public.listings l
    where l.status in ('removed', 'sold')
      and l.last_seen_at >= now() - make_interval(days => p_days)
      and l.duplicate_of is null
      and l.motorcycle_id is not null
      and l.price >= 300
  ),
  live as (
    select l.motorcycle_id, public.market_position(l) as position
    from public.listings l
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
  ),
  per_gone as (
    select g.motorcycle_id,
           count(*)::integer as gone,
           count(*) filter (where g.kind = 'sold_in_text')::integer as sold_in_text,
           count(*) filter (where g.kind = 'likely_sold')::integer as likely_sold,
           count(*) filter (where g.kind = 'relisted')::integer as relisted,
           count(*) filter (where g.kind = 'still_listed')::integer as still_listed,
           count(*) filter (where g.kind = 'expired')::integer as expired,
           count(*) filter (where g.kind = 'seen_once')::integer as seen_once,
           count(g.position) filter (where g.kind in ('sold_in_text', 'likely_sold'))::integer
             as sold_with_position,
           round((percentile_cont(0.5) within group (order by g.position)
                  filter (where g.kind in ('sold_in_text', 'likely_sold')))::numeric, 1)
             as sold_position,
           count(*) filter (where g.kind in ('sold_in_text', 'likely_sold')
                              and g.drop_pct >= 1)::integer as sold_dropped,
           round((percentile_cont(0.5) within group (order by g.drop_pct)
                  filter (where g.kind in ('sold_in_text', 'likely_sold')
                            and g.drop_pct >= 1))::numeric, 1)
             as sold_drop_pct,
           round((percentile_cont(0.5) within group (order by g.days)
                  filter (where g.kind in ('sold_in_text', 'likely_sold')))::numeric, 0)
             as sold_days
    from gone g
    group by g.motorcycle_id
  ),
  per_live as (
    select v.motorcycle_id,
           count(v.position)::integer as live_with_position,
           round((percentile_cont(0.5) within group (order by v.position))::numeric, 1)
             as live_position
    from live v
    group by v.motorcycle_id
  )
  select m.brand || ' ' || m.model,
         g.gone, g.sold_in_text, g.likely_sold, g.relisted, g.still_listed,
         g.expired, g.seen_once, g.sold_with_position, g.sold_position,
         coalesce(v.live_with_position, 0), v.live_position,
         g.sold_dropped, g.sold_drop_pct, g.sold_days
  from per_gone g
  join public.motorcycles m on m.id = g.motorcycle_id
  left join per_live v on v.motorcycle_id = g.motorcycle_id
  order by g.gone desc, 1;
$$;

revoke all on function public.score_check_models(integer)
  from public, anon, authenticated;
grant execute on function public.score_check_models(integer) to service_role;
