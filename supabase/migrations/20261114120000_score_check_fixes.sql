-- N.92: what the first score check (N.61) showed was off.
--
-- 1. Ads seen by a single run. 16 of the CB650R's 26 "likely sales" were
--    found by one import on the collector's first day (19 Oct) and never
--    seen again: no publication date, no search key, removed that night.
--    An ad no second run saw tells nothing of how it left, so it is now
--    'seen_once', not a likely sale: exit prices, quick good deals and the
--    score check leave it out.
-- 2. The Deal Score bands. last_deal_score was kept from 12 Nov
--    (20261112110000_likely_sales.sql), filled only for ads still scored
--    then: the ads that had sold before had none and were left out, so
--    every band read 0 % sold. The bands now count only ads first found
--    since then (p_since), and fill in as the weeks go by.

-- How a gone ad left the market, as far as we can tell (null while live):
--   sold_in_text  the seller wrote that it was sold or reserved;
--   relisted      the same bike was put up again (mark_relists);
--   still_listed  the same bike is still live in another ad (a duplicate);
--   expired       a private seller's ad gone when its 30 days ran out
--                 (dealers' ads don't expire on Standvirtual's plans);
--   seen_once     only one run saw it (under an hour between first and
--                 last seen): how long it lasted and why it left are
--                 unknown;
--   likely_sold   none of these: most likely sold, never certain.
create or replace function public.exit_kind(l public.listings)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when l.status not in ('removed', 'sold') then null
    when l.status = 'sold' or l.sold_marked_at is not null then 'sold_in_text'
    when exists (
      select 1 from public.listings r where r.relisted_from = l.id
    ) then 'relisted'
    when exists (
      select 1 from public.listings o
      where o.id <> l.id
        and o.status in ('active', 'price_changed')
        and (o.duplicate_of = l.id
             or o.id = l.duplicate_of
             or o.duplicate_of = l.duplicate_of)
    ) then 'still_listed'
    when l.seller_type <> 'dealer'
     and public.ended_at_expiry(l.published_at, l.site_refreshed_at, l.last_seen_at)
    then 'expired'
    when l.last_seen_at - l.first_seen_at < interval '1 hour' then 'seen_once'
    else 'likely_sold'
  end
$$;

-- The score check per model, with the ads only one run saw counted apart.
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
           round((percentile_cont(0.5) within group (order by g.drop_pct)
                  filter (where g.kind in ('sold_in_text', 'likely_sold')))::numeric, 1)
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
         g.sold_drop_pct, g.sold_days
  from per_gone g
  join public.motorcycles m on m.id = g.motorcycle_id
  left join per_live v on v.motorcycle_id = g.motorcycle_id
  order by g.gone desc, 1;
$$;

revoke all on function public.score_check_models(integer)
  from public, anon, authenticated;
grant execute on function public.score_check_models(integer) to service_role;

-- The bands: ads first seen in the last p_days days and at least p_horizon
-- days ago, and not before p_since (when last Deal Scores began to be
-- kept; before it only the ads still scored then have one), as before.
drop function public.score_check_bands(integer, integer);
create function public.score_check_bands(
  p_days integer default 60,
  p_horizon integer default 14,
  p_since timestamptz default '2026-11-12 13:10+00'
)
returns table(band text, ads integer, sold_within integer, share numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with ads as (
    select case
             when l.last_deal_score >= 80 then '80-100'
             when l.last_deal_score >= 60 then '60-79'
             when l.last_deal_score >= 40 then '40-59'
             else '0-39'
           end as band,
           public.exit_kind(l) in ('sold_in_text', 'likely_sold')
             and l.last_seen_at - l.first_seen_at
                 <= make_interval(days => p_horizon) as sold
    from public.listings l
    where l.first_seen_at >= now() - make_interval(days => p_days)
      and l.first_seen_at <= now() - make_interval(days => p_horizon)
      and l.first_seen_at >= p_since
      and (l.published_at is null
           or l.published_at >= l.first_seen_at - interval '2 days')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
      and l.price >= 300
      and l.last_deal_score is not null
  )
  select a.band,
         count(*)::integer,
         count(*) filter (where a.sold)::integer,
         round(100.0 * count(*) filter (where a.sold) / count(*), 1)
  from ads a
  group by a.band
  order by a.band desc;
$$;

revoke all on function public.score_check_bands(integer, integer, timestamptz)
  from public, anon, authenticated;
grant execute on function public.score_check_bands(integer, integer, timestamptz)
  to service_role;
