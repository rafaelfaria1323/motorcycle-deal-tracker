-- "A minha mota" with any model (N.120): a bike of a model nobody follows
-- can be kept, and its model stays collected while someone owns it, from
-- three years before the oldest owned bike, so its monthly value
-- (record_owned_bike_values) keeps comparables. Selling (deleting) the
-- last such bike lets the model go as before.

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
  v_owned_min integer;
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

  -- Bikes someone owns: their value is kept every month.
  select min(greatest(b.year - 3, 1990)) into v_owned_min
  from public.owned_bikes b
  where b.motorcycle_id = p_motorcycle_id;

  v_now := v_followed or v_request_min is not null or v_owned_min is not null;
  -- least() ignores nulls: whichever is known.
  v_min := least(v_follow_min, v_request_min, v_owned_min);

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

revoke all on function public.refresh_collected_model(uuid)
  from public, anon, authenticated;

-- An owned bike added, moved to another model or year, or deleted.
create or replace function public.owned_bikes_collect_model()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_collected_model(old.motorcycle_id);
  end if;
  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and new.motorcycle_id <> old.motorcycle_id) then
    perform public.refresh_collected_model(new.motorcycle_id);
  end if;
  return null;
end;
$$;

revoke all on function public.owned_bikes_collect_model()
  from public, anon, authenticated;

create trigger owned_bikes_collect_model
after insert or update of motorcycle_id, year or delete on public.owned_bikes
for each row execute function public.owned_bikes_collect_model();

-- Bikes already kept.
select public.refresh_collected_model(m.id)
from public.motorcycles m
where exists (select 1 from public.owned_bikes b where b.motorcycle_id = m.id)
  and not m.is_active;
