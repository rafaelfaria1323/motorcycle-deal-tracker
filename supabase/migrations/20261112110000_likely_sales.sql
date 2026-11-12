-- N.61: which gone ads were likely sold, and a weekly check of the
-- estimates against them.
--
-- Neither site says that a bike was sold: an ad only disappears. It may
-- have been sold, have expired (both sites run an ad for 30 days unless
-- it is renewed), be listed again later (a relist) or still be on sale on
-- the other site (a duplicate still live). The status 'sold' is never set
-- (nothing tells us), and 'removed' keeps meaning "gone" everywhere it is
-- used (alerts, a relist coming back). What is known about how an ad left
-- is worked out by exit_kind() instead.

-- The seller says it is sold or reserved: "VENDIDA" in OLX's title (the
-- variant) or at the start of the description, or "já vendida" / "está
-- reservada" anywhere in it. Not when the word only describes how the bike
-- is sold ("vendida com garantia", "vendido no estado em que se
-- encontra"), nor after a denial ("ainda não está vendida").
create or replace function public.sold_in_text(p_variant text, p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with t as (
    select lower(coalesce(p_variant, '')) as variant,
           lower(coalesce(p_description, '')) as description,
           -- The word on its own, not how the bike is sold.
           '\m(vendid|reservad)[oa]s?\M(?!\s*(com|sem|no|na|nos|nas|em|ao|aos|à|a|pelo|pela|por|para|c/|s/|apenas|só|so|tal|como|ja|já|nova|novo|nunca)(\s|$|[[:punct:]]))'
             as bare,
           -- "não está vendida", "ainda não foi reservada".
           '\mn[aã]o\s+((est[aá]|foi|ser[aá]|se\s+encontra)\s+)?(vendid|reservad)[oa]s?\M'
             as denied
  )
  select (t.variant ~ t.bare
          or t.variant ~ '\msold\M'
          or left(t.description, 60) ~ t.bare
          or t.description ~
               '\m(j[aá]|est[aá]|encontra-se)\s+(vendid|reservad)[oa]s?\M(?!\s*(a|com|em|no|na|para|por|pelo|pela)(\s|$|[[:punct:]]))')
     and not (t.variant ~ t.denied or t.description ~ t.denied)
  from t
$$;

revoke all on function public.sold_in_text(text, text)
  from public, anon, authenticated;
grant execute on function public.sold_in_text(text, text) to service_role;

-- When the ad last said so (null once it doesn't: a sale that fell
-- through). Read by exit_kind() once the ad is gone.
alter table public.listings
  add column sold_marked_at timestamptz;

comment on column public.listings.sold_marked_at is
  'When the ad''s title or description said it was sold or reserved (sold_in_text); null when it no longer does.';

create or replace function public.fill_sold_marked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.sold_in_text(new.variant, new.description) then
    new.sold_marked_at := coalesce(new.sold_marked_at, now());
  else
    new.sold_marked_at := null;
  end if;
  return new;
end;
$$;

revoke all on function public.fill_sold_marked()
  from public, anon, authenticated;

create trigger listings_sold_marked
before insert or update of variant, description on public.listings
for each row
execute function public.fill_sold_marked();

update public.listings
set sold_marked_at = last_seen_at
where public.sold_in_text(variant, description);

-- The last Deal Score a listing had: the scores of gone listings are
-- cleared, as last_pct_below_market keeps their last market position.
alter table public.listings
  add column last_deal_score smallint;

create or replace function public.keep_last_deal_score()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.last_deal_score := new.deal_score;
  return new;
end;
$$;

revoke all on function public.keep_last_deal_score()
  from public, anon, authenticated;

create trigger listings_keep_last_deal_score
before update of deal_score on public.listings
for each row
when (new.deal_score is not null
      and new.deal_score is distinct from old.deal_score)
execute function public.keep_last_deal_score();

update public.listings
set last_deal_score = deal_score
where deal_score is not null;

-- An ad that was last seen when its 30 days on the site ran out, counted
-- from its publication (renewals adding 30 days each) or from its last
-- renewal: from 2 days before to 1 day after such an end, since the ad is
-- last seen up to a day before it goes. Unknown dates: no.
create or replace function public.ended_at_expiry(
  p_published timestamptz,
  p_refreshed timestamptz,
  p_last_seen timestamptz
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_or(
           r.days >= 28
           and r.days - 30 * round(r.days / 30) between -2 and 1
         ), false)
  from (
    select extract(epoch from p_last_seen - d) / 86400 as days
    from unnest(array[p_published, p_refreshed]) d
    where d is not null and d <= p_last_seen
  ) r
$$;

revoke all on function public.ended_at_expiry(timestamptz, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.ended_at_expiry(timestamptz, timestamptz, timestamptz)
  to service_role;

-- How a gone ad left the market, as far as we can tell (null while live):
--   sold_in_text  the seller wrote that it was sold or reserved;
--   relisted      the same bike was put up again (mark_relists);
--   still_listed  the same bike is still live in another ad (a duplicate);
--   expired       a private seller's ad gone when its 30 days ran out
--                 (dealers' ads don't expire on Standvirtual's plans);
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
    else 'likely_sold'
  end
$$;

revoke all on function public.exit_kind(public.listings) from public;
grant execute on function public.exit_kind(public.listings)
  to anon, authenticated, service_role;

-- "Último preço pedido antes de sair": as before, but only ads that were
-- likely sold (exit_kind), not those that expired, came back or are
-- still on sale elsewhere.
create or replace function public.exit_price(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null,
  p_except uuid default null
)
returns table(gone_count integer, median_price numeric)
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
      and public.exit_kind(c) in ('sold_in_text', 'likely_sold')
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

-- The weekly check (bin/score_check.dart), per model, over the ads gone in
-- the last p_days days (not duplicates, 300 € or more): how they left; for
-- the likely sales, where their last asking price sat against our estimate
-- (last_pct_below_market: + below, - above; ads whose text tells of
-- damage or legalisation left out, judged against another value), how
-- far it had dropped from the highest price seen and how long they were
-- up; and where the live ads sit now. When the sales sit well above the
-- estimate, the estimate is low (and the other way round).
create or replace function public.score_check_models(p_days integer default 28)
returns table(
  model text,
  gone integer,
  sold_in_text integer,
  likely_sold integer,
  relisted integer,
  still_listed integer,
  expired integer,
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
         g.expired, g.sold_with_position, g.sold_position,
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

-- Whether the Deal Score finds the bikes that sell: of the ads we saw go
-- up in the last p_days days and at least p_horizon days ago (not
-- duplicates, 300 € or more, scored; an ad published well before we first
-- saw it is left out, its start unknown), the share each band of its last
-- Deal Score saw likely sold within p_horizon days. Excellent deals should
-- go first.
create or replace function public.score_check_bands(
  p_days integer default 60,
  p_horizon integer default 14
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

revoke all on function public.score_check_bands(integer, integer)
  from public, anon, authenticated;
grant execute on function public.score_check_bands(integer, integer) to service_role;
