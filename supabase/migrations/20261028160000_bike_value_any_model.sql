-- "Quanto vale a minha mota" for any brand and model (16.9): an account
-- may ask for the value of a model nobody follows, or of a year the
-- collection doesn't reach yet. The request switches the model's
-- collection on for 30 days (from the bike's year minus 3, the
-- comparables' window); the next scheduled collection reads it, and the
-- collector answers the request with a notification
-- (answer_bike_value_requests). No extra fetching: the request waits for
-- the schedule (at most 2 h by day).

-- When the model's collection last started (null while it isn't
-- collected): a run that started after it has read the model's searches.
-- A model added already followed (add_catalog_model) starts now.
alter table public.motorcycles add column collected_since timestamptz default now();
update public.motorcycles
set collected_since = case when is_active then created_at end
where true;

create table public.bike_value_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  motorcycle_id uuid not null references public.motorcycles (id) on delete cascade,
  year          integer not null check (year between 1990 and 2100),
  mileage       integer check (mileage >= 0),
  requested_at  timestamptz not null default now(),
  -- Whether it had to wait for a collection (those count against the cap).
  waited        boolean not null,
  answered_at   timestamptz
);
create index bike_value_requests_user on public.bike_value_requests (user_id, requested_at desc);
create index bike_value_requests_model on public.bike_value_requests (motorcycle_id, requested_at desc);
create index bike_value_requests_pending on public.bike_value_requests (motorcycle_id)
  where answered_at is null;

alter table public.bike_value_requests enable row level security;
create policy "owners read their bike value requests"
  on public.bike_value_requests for select to authenticated
  using ((select auth.uid()) = user_id);

-- How long a request keeps its model collected.
create function public.bike_value_request_days()
returns integer
language sql
immutable
set search_path = ''
as $$ select 30 $$;

-- Collect the model while any account follows it or asked for its value in
-- the last 30 days, from the earliest year any of them needs (a request
-- needs its year minus 3, never before 1990). When collection starts or
-- stops, its listings get the model back or lose it.
create or replace function public.refresh_collected_model(p_motorcycle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_was boolean;
  v_now boolean;
  v_min integer;
  v_followed boolean;
  v_follow_min integer;
  v_request_min integer;
begin
  select m.is_active into v_was
  from public.motorcycles m where m.id = p_motorcycle_id
  for update;

  select count(*) > 0, min(u.min_year) into v_followed, v_follow_min
  from public.user_models u
  where u.motorcycle_id = p_motorcycle_id and u.tracked;

  -- min() is null without requests (greatest() would turn it into 1990).
  select min(greatest(r.year - 3, 1990)) into v_request_min
  from public.bike_value_requests r
  where r.motorcycle_id = p_motorcycle_id
    and r.requested_at > now()
        - pg_catalog.make_interval(days => public.bike_value_request_days());

  v_now := v_followed or v_request_min is not null;
  -- least() ignores nulls: whichever of the two is known.
  v_min := least(v_follow_min, v_request_min);

  update public.motorcycles
  set is_active = v_now,
      min_year = coalesce(v_min, min_year),
      collected_since = case
        when not v_now then null
        when v_was then collected_since
        else now()
      end,
      updated_at = now()
  where id = p_motorcycle_id;

  if v_now and not v_was then
    update public.listings l
    set motorcycle_id = m.id
    from public.motorcycles m
    where m.id = p_motorcycle_id
      and l.motorcycle_id is null
      and lower(l.brand) = lower(m.brand)
      and lower(l.model) = lower(m.model);
  elsif v_was and not v_now then
    update public.listings set motorcycle_id = null
    where motorcycle_id = p_motorcycle_id;
  end if;

  if v_now is distinct from v_was then
    perform public.recalculate_deal_scores();
  end if;
end;
$$;
revoke all on function public.refresh_collected_model(uuid) from public, anon, authenticated;

-- Whether the model's comparables for a bike of p_year are in the
-- database: collected from that year, by a run that started after its
-- collection did and finished well enough to be imported.
create function public.bike_value_ready(p_motorcycle_id uuid, p_year integer)
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
      and m.min_year <= greatest(p_year - 3, 1990)
      and exists (select 1 from public.collector_runs r
                  where r.started_at >= m.collected_since
                    and r.status in ('ok', 'partial'))
  )
$$;
revoke all on function public.bike_value_ready(uuid, integer) from public, anon, authenticated;

-- The catalog model of a brand and model typed or picked in the value form:
-- the one already there (same brand and model, any case), else a new one
-- nobody follows (the searches are filled as for any new model; the
-- request that follows switches its collection on). Same checks as
-- add_catalog_model.
create function public.bike_value_model(
  p_brand               text,
  p_model               text,
  p_olx_search          text default null,
  p_standvirtual_search text default null,
  p_engine_cc_min       integer default null,
  p_engine_cc_max       integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_brand text := normalize(btrim(p_brand), NFC);
  v_model text := normalize(btrim(p_model), NFC);
  v_slug text;
  v_id uuid;
  v_range int4range := public.engine_range_from_name(v_model);
begin
  perform public.require_account();

  if nullif(v_brand, '') is null or nullif(v_model, '') is null then
    raise exception 'Brand and model are required' using errcode = '22023';
  end if;
  if p_engine_cc_min not between 1 and 3000
     or p_engine_cc_max not between 1 and 3000
     or p_engine_cc_min > p_engine_cc_max then
    raise exception 'Engine size range %-% is invalid',
      p_engine_cc_min, p_engine_cc_max using errcode = '22023';
  end if;

  v_slug := btrim(regexp_replace(lower(v_brand || '-' || v_model),
                                 '[^a-z0-9]+', '-', 'g'), '-');

  select m.id into v_id
  from public.motorcycles m
  where (lower(m.brand) = lower(v_brand) and lower(m.model) = lower(v_model))
     or m.slug = v_slug
  order by m.is_active desc, m.created_at
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  if p_engine_cc_min is null and p_engine_cc_max is null then
    p_engine_cc_min := lower(v_range);
    p_engine_cc_max := upper(v_range) - 1;
  end if;

  insert into public.motorcycles
    (brand, model, slug, min_year, is_active, collected_since,
     olx_search, standvirtual_search, engine_cc_min, engine_cc_max)
  values
    (v_brand, v_model, v_slug, extract(year from now())::integer, false, null,
     nullif(btrim(p_olx_search), ''),
     nullif(btrim(p_standvirtual_search), ''),
     p_engine_cc_min, p_engine_cc_max)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.bike_value_model(text, text, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.bike_value_model(text, text, text, text, integer, integer)
  to authenticated;

-- Asks for the value of a bike: ready now when the model's comparables for
-- that year are in the database (the app then shows bike_value at once);
-- otherwise the model is collected from the next scheduled run and the
-- collector answers. At most 3 requests a day that wait (free for now, a
-- paid feature later: docs/paid-plans.md); an identical one still waiting
-- is returned instead of a new one.
create function public.request_bike_value(
  p_motorcycle_id uuid,
  p_year          integer,
  p_mileage       integer default null
)
returns table (request_id uuid, ready boolean)
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

  v_ready := public.bike_value_ready(p_motorcycle_id, p_year);

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
revoke all on function public.request_bike_value(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.request_bike_value(uuid, integer, integer)
  to authenticated;

-- The collector, at the end of a run that started at p_started_at: the
-- requests still waiting whose model was being collected when the run
-- started (so it was in the run's searches), marked answered, with the
-- value to tell their owner. Only once the run saw one of the model's ads
-- (a site paused or out of time may not have read it), or a day after the
-- request (the model may have no ads at all: "too few listings").
create function public.answer_bike_value_requests(p_started_at timestamptz)
returns table (
  id               uuid,
  user_id          uuid,
  brand            text,
  model            text,
  year             integer,
  mileage          integer,
  comparable_count integer,
  fair_price       numeric
)
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
      and m.min_year <= greatest(r.year - 3, 1990)
      and (r.requested_at < now() - interval '1 day'
           or exists (select 1 from public.listings l
                      where l.motorcycle_id = m.id
                        and l.last_seen_at >= p_started_at))
    returning r.id, r.user_id, r.motorcycle_id, r.year, r.mileage
  )
  select a.id, a.user_id, m.brand, m.model, a.year, a.mileage,
         v.comparable_count, v.fair_price
  from answered a
  join public.motorcycles m on m.id = a.motorcycle_id
  cross join lateral public.bike_value(a.motorcycle_id, a.year, a.mileage) v
  order by a.id;
end;
$$;
revoke all on function public.answer_bike_value_requests(timestamptz)
  from public, anon, authenticated;
grant execute on function public.answer_bike_value_requests(timestamptz) to service_role;

-- Daily: models whose last request is over 30 days old (and that nobody
-- follows) stop being collected.
create function public.expire_bike_value_models()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_model uuid;
  v_count integer := 0;
begin
  for v_model in
    select m.id
    from public.motorcycles m
    where m.is_active
      and exists (select 1 from public.bike_value_requests r
                  where r.motorcycle_id = m.id)
      and not exists (
        select 1 from public.bike_value_requests r
        where r.motorcycle_id = m.id
          and r.requested_at > now()
              - pg_catalog.make_interval(days => public.bike_value_request_days()))
  loop
    perform public.refresh_collected_model(v_model);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.expire_bike_value_models() from public, anon, authenticated;

select cron.schedule(
  'expire-bike-value-models',
  '29 3 * * *',
  $job$ select public.expire_bike_value_models() $job$
);
