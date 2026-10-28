-- Time to sale per listing (10.4): how much longer a live ad is likely to
-- stay on the market, from the model's other ads, counted the way
-- survival is (Kaplan-Meier): an ad still live is known to have lasted at
-- least its age, so long-lived ads are not left out as a median of the
-- gone ones alone would. Conditioned on how long this ad has been up, and,
-- once enough ads have left at a similar price for their year and mileage,
-- only those ads. Gone means removed or sold: we can't tell which.

-- Where a listing's price sat against its estimated value when it was last
-- scored. The scores of gone listings are cleared, so this keeps the last
-- one for the ads that leave the market from now on.
alter table public.listings
  add column last_pct_below_market numeric;

create or replace function public.keep_market_position()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.last_pct_below_market :=
    (new.score_breakdown ->> 'pct_below_market')::numeric;
  return new;
end;
$$;

revoke all on function public.keep_market_position()
  from public, anon, authenticated;

create trigger listings_keep_market_position
before update of score_breakdown on public.listings
for each row
when (new.score_breakdown ->> 'pct_below_market' is not null
      and new.score_breakdown ->> 'pct_below_market'
          is distinct from old.score_breakdown ->> 'pct_below_market')
execute function public.keep_market_position();

update public.listings
set last_pct_below_market = (score_breakdown ->> 'pct_below_market')::numeric
where score_breakdown ->> 'pct_below_market' is not null;

-- The price band: 'below' at 5 % or more under the estimate, 'above' at
-- 5 % or more over it, else 'near'; null without an estimate.
create or replace function public.market_band(p_pct_below numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_pct_below is null then null
    when p_pct_below >= 5 then 'below'
    when p_pct_below <= -5 then 'above'
    else 'near'
  end
$$;

-- Days until half the ads that lasted [p_age] days had left: the
-- Kaplan-Meier survival of ([p_days], [p_gone]) pairs (gone: left after
-- that many days; else still live at that age), conditioned on lasting
-- p_age, and the first time it falls to half or less, minus p_age. Null
-- when it never does (too few ads lasted that long). Pure: plain values.
create or replace function public.median_days_remaining(
  p_days numeric[],
  p_gone boolean[],
  p_age numeric
)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  at_risk bigint;
  survival numeric := 1;
  at_age numeric;
  r record;
begin
  select count(*) into at_risk
  from unnest(p_days, p_gone) u(days, gone)
  where u.days is not null;

  for r in
    select u.days,
           count(*) filter (where u.gone) as left_then,
           count(*) as ended_then
    from unnest(p_days, p_gone) u(days, gone)
    where u.days is not null
    group by u.days
    order by u.days
  loop
    -- The survival just before this time is the one at the ad's age.
    if r.days > p_age and at_age is null then
      at_age := survival;
    end if;
    survival := survival * (1 - r.left_then::numeric / at_risk);
    at_risk := at_risk - r.ended_then;
    -- (With a margin for the rounding of thirds and the like.)
    if at_age is not null and r.left_then > 0
       and survival <= at_age / 2 + 1e-9 then
      return r.days - p_age;
    end if;
  end loop;
  return null;
end;
$$;

-- The estimate for one live listing, from its model's other non-duplicate
-- ads (the ad itself, the one it repeats and its own repeats left out).
-- The price band's ads only when 5 or more of them have left; else every
-- ad of the model (band null). remaining_days null: the listing is not
-- live, or too few ads lasted as long as it has; typical_days the same
-- from day 0. Security invoker: listings are readable by everyone.
create or replace function public.listing_time_to_sale(p_listing_id uuid)
returns table (
  band text,
  gone_count integer,
  live_count integer,
  days_listed integer,
  typical_days integer,
  remaining_days integer
)
language plpgsql
stable
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

  -- A gone ad's band is where it was when last scored.
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

revoke all on function public.listing_time_to_sale(uuid) from public;
grant execute on function public.listing_time_to_sale(uuid)
  to anon, authenticated;
