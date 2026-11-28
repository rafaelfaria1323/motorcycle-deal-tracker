-- How fast good deals go (N.138), in the weekly score check (N.61): per
-- Deal Score band, how long after an ad went up the collection found it,
-- how long the likely sales stayed up, how many went within a day, how
-- many only one run saw, and how long after publication the first alert
-- came. If the best ads go within hours, the limit is how often we
-- collect, not the scoring. A report only: nothing is written.

-- Ads first seen since p_since, in the last p_days days and a day ago or
-- more (each had a day to go), published at most 2 days before they were
-- found (older ones are ads of a model just followed, not a measure of
-- how fast the collection finds new ads); not duplicates, 300 € or more,
-- with a last Deal Score. Hours are medians, from the publication.
-- night_* are the ads published from 00:00 to 08:00 Lisbon time, the
-- longest gap between collections. A likely sale is exit_kind's
-- sold_in_text or likely_sold; seen_once is an ad one run saw.
create function public.score_check_speed(
  p_days integer default 60,
  p_since timestamptz default '2026-11-12 13:10+00'
) returns table (
  band text,
  ads integer,
  found_hours numeric,
  found_p90_hours numeric,
  night_ads integer,
  night_found_hours numeric,
  sales integer,
  sales_within_day integer,
  sale_hours numeric,
  seen_once integer,
  alerted integer,
  alert_hours numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with ads as (
    select case
             when l.last_deal_score >= 80 then '80-100'
             when l.last_deal_score >= 60 then '60-79'
             else '0-59'
           end as band,
           greatest(extract(epoch from l.first_seen_at - l.published_at), 0) / 3600
             as found_hours,
           extract(hour from l.published_at at time zone 'Europe/Lisbon') < 8 as night,
           public.exit_kind(l) as kind,
           greatest(extract(epoch from l.last_seen_at - l.published_at), 0) / 3600
             as up_hours,
           (select min(a.created_at)
            from public.alerts a
            where a.listing_id = l.id
              and a.type <> 'listing_removed') as first_alert,
           l.published_at
    from public.listings l
    where l.first_seen_at >= greatest(p_since,
                                      now() - make_interval(days => greatest(p_days, 2)))
      and l.first_seen_at <= now() - interval '1 day'
      and l.published_at is not null
      and l.published_at >= l.first_seen_at - interval '2 days'
      and l.duplicate_of is null
      and l.motorcycle_id is not null
      and l.price >= 300
      and l.last_deal_score is not null
  ),
  timed as (
    select a.*,
           a.kind in ('sold_in_text', 'likely_sold') as sale,
           -- greatest ignores nulls: no alert must stay null, not 0 h.
           case when a.first_alert is not null
                then greatest(extract(epoch from a.first_alert - a.published_at), 0) / 3600
           end as alert_hours
    from ads a
  )
  select t.band,
         count(*)::integer,
         round((percentile_cont(0.5) within group (order by t.found_hours))::numeric, 1),
         round((percentile_cont(0.9) within group (order by t.found_hours))::numeric, 1),
         count(*) filter (where t.night)::integer,
         round((percentile_cont(0.5) within group (order by t.found_hours)
                filter (where t.night))::numeric, 1),
         count(*) filter (where t.sale)::integer,
         count(*) filter (where t.sale and t.up_hours <= 24)::integer,
         round((percentile_cont(0.5) within group (order by t.up_hours)
                filter (where t.sale))::numeric, 1),
         count(*) filter (where t.kind = 'seen_once')::integer,
         count(t.first_alert)::integer,
         round((percentile_cont(0.5) within group (order by t.alert_hours))::numeric, 1)
  from timed t
  group by t.band
  order by t.band desc;
$$;

revoke all on function public.score_check_speed(integer, timestamptz)
  from public, anon, authenticated;
grant execute on function public.score_check_speed(integer, timestamptz) to service_role;
