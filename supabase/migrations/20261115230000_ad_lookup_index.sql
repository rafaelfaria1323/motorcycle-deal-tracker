-- B.5 (docs/bug-hunt.md 2.1, 2.2).
--
-- (1) listing_for_ad looked an ad up by a regular expression over every
-- listing of the site. An index on the same expression (it must stay the
-- query's exact text) makes it one index read; three places call it, the
-- computed field ad_listing once per request row.
--
-- (2) A valuation was "ready" with 5 ads within 3 years, counted with or
-- without a mileage, while bike_value leaves out ads without one when the
-- bike has one: a ready request could still be answered with fewer than 3
-- comparables. The count now takes the bike's mileage and uses
-- bike_value's rule.

create index listings_ad_code
  on public.listings (source, substring(url from '-(ID[0-9A-Za-z]+)\.html'));

drop function public.near_comparable_count(uuid, integer);

create function public.near_comparable_count(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null
)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.listings c
  where c.motorcycle_id = p_motorcycle_id
    and c.status in ('active', 'price_changed')
    and c.duplicate_of is null
    and c.price >= 300
    and abs(p_year - c.year) <= 3
    and (p_mileage is null or c.mileage is not null)
$$;

revoke all on function public.near_comparable_count(uuid, integer, integer)
  from public, anon, authenticated;

drop function public.bike_value_ready(uuid, integer);

create function public.bike_value_ready(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.motorcycles m
    where m.id = p_motorcycle_id
      and m.is_active
      and (m.min_year <= greatest(p_year - 3, 1990)
           or public.near_comparable_count(m.id, p_year, p_mileage) >= 5)
      and exists (select 1 from public.collector_runs r
                  where r.started_at >= m.collected_since
                    and r.status in ('ok', 'partial'))
  )
$$;

revoke all on function public.bike_value_ready(uuid, integer, integer)
  from public, anon, authenticated;

create or replace function public.request_bike_value(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null
)
returns table(request_id uuid, ready boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ready boolean;
  v_id uuid;
begin
  perform public.require_account();

  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
  if p_year < 1990 or p_year > extract(year from now())::integer + 1 then
    raise exception 'Year % is out of range', p_year using errcode = '22023';
  end if;
  if p_mileage < 0 then
    raise exception 'Mileage % is invalid', p_mileage using errcode = '22023';
  end if;

  v_ready := public.bike_value_ready(p_motorcycle_id, p_year, p_mileage);

  if not v_ready then
    select r.id into v_id
    from public.bike_value_requests r
    where r.user_id = auth.uid()
      and r.motorcycle_id = p_motorcycle_id
      and r.year = p_year
      and r.mileage is not distinct from p_mileage
      and r.answered_at is null
    limit 1;
    if v_id is not null then
      return query select v_id, false;
      return;
    end if;

    if (select count(*) from public.bike_value_requests r
        where r.user_id = auth.uid() and r.waited
          and r.requested_at > now() - interval '1 day') >= 3 then
      raise exception 'At most 3 valuations that wait for a collection a day'
        using errcode = '54000';
    end if;
  end if;

  insert into public.bike_value_requests
    (motorcycle_id, year, mileage, waited, answered_at)
  values
    (p_motorcycle_id, p_year, p_mileage, not v_ready,
     case when v_ready then now() end)
  returning id into v_id;

  -- A ready request also keeps the model collected (its figures stay
  -- fresh for the next 30 days' requests).
  perform public.refresh_collected_model(p_motorcycle_id);

  return query select v_id, v_ready;
end;
$$;

create or replace function public.answer_bike_value_requests(p_started_at timestamptz)
returns table(id uuid, user_id uuid, brand text, model text, year integer, mileage integer,
              comparable_count integer, fair_price numeric, is_ad boolean, listing_id uuid,
              deal_score smallint, risk_score smallint)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with answered as (
    update public.bike_value_requests r
    set answered_at = now()
    from public.motorcycles m
    where r.answered_at is null
      and m.id = r.motorcycle_id
      and m.is_active
      and m.collected_since <= p_started_at
      and (m.min_year <= greatest(r.year - 3, 1990)
           or public.near_comparable_count(m.id, r.year, r.mileage) >= 5)
      and (r.requested_at < now() - interval '1 day'
           or (r.ad_url is null
               and exists (select 1 from public.listings l
                           where l.motorcycle_id = m.id
                             and l.last_seen_at >= p_started_at))
           or (r.ad_url is not null
               and exists (select 1 from public.listings l
                           where l.id = public.listing_for_ad(r.ad_url)
                             and l.last_seen_at >= p_started_at)))
    returning r.id, r.user_id, r.motorcycle_id, r.year, r.mileage, r.ad_url
  )
  select a.id, a.user_id, m.brand, m.model, a.year, a.mileage,
         v.comparable_count, v.fair_price,
         a.ad_url is not null, l.id, l.deal_score, l.risk_score
  from answered a
  join public.motorcycles m on m.id = a.motorcycle_id
  cross join lateral public.bike_value(a.motorcycle_id, a.year, a.mileage) v
  left join public.listings l
    on a.ad_url is not null and l.id = public.listing_for_ad(a.ad_url)
  order by a.id;
end;
$$;

revoke all on function public.answer_bike_value_requests(timestamptz)
  from public, anon, authenticated;
