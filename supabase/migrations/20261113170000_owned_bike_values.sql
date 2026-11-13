-- "A minha mota" over time (N.80): once a month each bike's value is kept
-- (`bike_value` at the bike's year and its mileage that day: the km at
-- purchase plus the owner's km a year, as the app's `mileageNow`), so the
-- app can show how it went and the owner is told how much it changed
-- since the month before. Recorded by the Monday summary job; the first
-- Monday of a month makes the month's row. Owner-only reads; written only
-- by the collector (service role).
create table public.owned_bike_values (
  bike_id     uuid not null references public.owned_bikes (id) on delete cascade,
  -- The first day of the Lisbon month the value is for.
  month       date not null check (month = date_trunc('month', month)::date),
  value       numeric(10, 2) not null check (value > 0),
  mileage     integer,
  comparables integer not null,
  recorded_at timestamptz not null default now(),
  primary key (bike_id, month)
);

alter table public.owned_bike_values enable row level security;

revoke all on public.owned_bike_values from public, anon, authenticated;
grant select on public.owned_bike_values to authenticated;

create policy "Accounts read their own bikes' values"
  on public.owned_bike_values
  for select to authenticated
  using (
    exists (select 1 from public.owned_bikes b
            where b.id = bike_id and b.user_id = (select auth.uid()))
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  );

-- A month's value needs this many live ads behind it (as the Deal Score's
-- price slice): one or two ads would make the monthly change noise.
create function public.owned_bike_value_min_comparables()
returns integer
language sql
immutable
set search_path = ''
as $$ select 3 $$;

-- The mileage of a bike on [p_day]: the km at purchase plus [p_km_per_year]
-- for the time since, rounded to 100 km (= the app's `mileageNow`); null
-- when the km at purchase is unknown.
create function public.owned_bike_mileage(
  p_mileage_at_purchase integer,
  p_bought_on date,
  p_km_per_year integer,
  p_day date
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_mileage_at_purchase is null then null
    when p_day <= p_bought_on then p_mileage_at_purchase
    else (round((p_mileage_at_purchase
                 + p_km_per_year * (p_day - p_bought_on) / 365.25) / 100) * 100)::integer
  end
$$;

-- Keeps this Lisbon month's value of every bike of a real account that has
-- none yet and enough comparables, and returns the rows it kept with the
-- bike's latest earlier value (null for its first) for the notification.
-- Running it again in the same month keeps and returns nothing.
create function public.record_owned_bike_values(p_at timestamptz default now())
returns table (
  user_id        uuid,
  bike_id        uuid,
  brand          text,
  model          text,
  year           integer,
  value          numeric,
  mileage        integer,
  previous_value numeric,
  previous_month date
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day   date := (p_at at time zone 'Europe/Lisbon')::date;
  v_month date := date_trunc('month', v_day)::date;
begin
  return query
  with due as (
    select b.id, b.user_id, b.motorcycle_id, b.year::integer as year,
           public.owned_bike_mileage(b.mileage_at_purchase, b.bought_on,
                                     coalesce(s.km_per_year, 5000), v_day) as km
    from public.owned_bikes b
    join auth.users u on u.id = b.user_id and not coalesce(u.is_anonymous, false)
    left join public.ownership_settings s on s.user_id = b.user_id
    where b.bought_on <= v_day
      and not exists (select 1 from public.owned_bike_values v
                      where v.bike_id = b.id and v.month = v_month)
  ),
  valued as (
    select d.id, d.km, bv.fair_price, bv.comparable_count
    from due d
    cross join lateral public.bike_value(d.motorcycle_id, d.year, d.km) bv
    where bv.comparable_count >= public.owned_bike_value_min_comparables()
      and bv.fair_price > 0
  ),
  kept as (
    insert into public.owned_bike_values as v
      (bike_id, month, value, mileage, comparables, recorded_at)
    select x.id, v_month, x.fair_price, x.km, x.comparable_count, p_at
    from valued x
    on conflict on constraint owned_bike_values_pkey do nothing
    returning v.bike_id, v.value, v.mileage
  )
  select b.user_id, k.bike_id, m.brand::text, m.model::text, b.year::integer,
         k.value, k.mileage, p.value, p.month
  from kept k
  join public.owned_bikes b on b.id = k.bike_id
  join public.motorcycles m on m.id = b.motorcycle_id
  left join lateral (
    select e.value, e.month from public.owned_bike_values e
    where e.bike_id = k.bike_id and e.month < v_month
    order by e.month desc limit 1
  ) p on true
  order by b.user_id, k.bike_id;
end;
$$;

revoke all on function public.owned_bike_value_min_comparables() from public, anon, authenticated;
revoke all on function public.owned_bike_mileage(integer, date, integer, date) from public, anon, authenticated;
revoke all on function public.record_owned_bike_values(timestamptz) from public, anon, authenticated;
grant execute on function public.record_owned_bike_values(timestamptz) to service_role;

-- The test notification of the monthly value (push-test.yml's `kind`).
create or replace function public.start_workflow(p_workflow text, p_kind text default null)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token    text;
  v_response extensions.http_response;
  v_at       timestamptz;
begin
  if p_workflow in ('push-test.yml', 'weekly-summary.yml') then
    perform public.require_account();
  else
    perform public.require_admin();
  end if;
  if p_workflow is null
     or p_workflow not in ('collect.yml', 'weekly-summary.yml', 'push-test.yml') then
    raise exception 'unknown workflow %', p_workflow using errcode = '22023';
  end if;
  if p_kind is not null and (p_workflow <> 'push-test.yml' or p_kind not in (
       'test', 'new_listing', 'price_reduction', 'excellent_opportunity',
       'listing_removed', 'back_on_market', 'target_price_reached',
       'run_failed', 'run_blocked', 'run_recovered', 'visit_reminder',
       'bike_value_month')) then
    raise exception 'unknown kind %', p_kind using errcode = '22023';
  end if;

  -- One at a time per workflow, so two taps can't both pass the check.
  perform pg_advisory_xact_lock(hashtext('start_workflow ' || p_workflow));
  if exists (select 1 from public.workflow_starts w
             where w.workflow = p_workflow
               and (p_workflow = 'collect.yml' or w.started_by = auth.uid())
               and w.started_at > now() - case p_workflow
                 when 'collect.yml' then interval '15 minutes'
                 when 'push-test.yml' then interval '30 seconds'
                 else interval '2 minutes' end) then
    raise exception '% was started too recently', p_workflow
      using errcode = '55006';
  end if;

  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s where s.name = 'github_dispatch_token';
  if v_token is null then
    raise exception 'github_dispatch_token is not in the Vault' using errcode = '55000';
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '15000');
  v_response := extensions.http((
    'POST',
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
      || '/actions/workflows/' || p_workflow || '/dispatches',
    array[extensions.http_header('Authorization', 'Bearer ' || v_token),
          extensions.http_header('Accept', 'application/vnd.github+json'),
          extensions.http_header('X-GitHub-Api-Version', '2022-11-28'),
          extensions.http_header('User-Agent', 'motorcycle-deal-tracker')],
    'application/json',
    case p_workflow
      when 'weekly-summary.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object('account', auth.uid()))::text
      when 'push-test.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object(
                             'account', auth.uid(),
                             'kind', coalesce(p_kind, 'test')))::text
      else '{"ref": "main"}'
    end
  )::extensions.http_request);

  -- 204 = started (200 when GitHub answers with the run's details).
  if v_response.status not in (200, 204) then
    raise exception 'GitHub answered % to %', v_response.status, p_workflow
      using errcode = '58000';
  end if;

  insert into public.workflow_starts (workflow, started_by)
  values (p_workflow, auth.uid())
  returning started_at into v_at;
  return v_at;
end;
$$;
