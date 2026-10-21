-- Each account chooses its own models and the first year of each ("MT-07
-- from 2026" for one, "CBR650R from 2025" for another), while the
-- collection stays one: the collector runs the searches of every model any
-- account follows, from the earliest year any of them asks for, so all
-- accounts share the same listings, prices and scores.
--
-- motorcycles.is_active and min_year keep their meaning for the collector
-- (collect this model, from this year): they are now worked out from the
-- accounts' choices (refresh_collected_model), so the collector and its
-- searches are unchanged. What each account sees and is alerted about
-- follows its own list.
--
-- A new account starts with an empty list. Anonymous sessions can't choose
-- models: they see every collected model.

create table public.user_models (
  user_id       uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  motorcycle_id uuid not null references public.motorcycles (id) on delete cascade,
  -- false keeps a year chosen for a model the account doesn't follow.
  tracked       boolean not null default true,
  min_year      integer not null check (min_year between 1990 and 2100),
  updated_at    timestamptz not null default now(),
  primary key (user_id, motorcycle_id)
);

create index user_models_motorcycle_id_idx on public.user_models (motorcycle_id);

-- Read by its owner; written only through the catalog RPCs below.
alter table public.user_models enable row level security;

create policy "Users read their own models"
  on public.user_models
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- The accounts that exist follow what is collected today.
insert into public.user_models (user_id, motorcycle_id, min_year)
select u.id, m.id, m.min_year
from auth.users u
cross join public.motorcycles m
where not coalesce(u.is_anonymous, false)
  and m.is_active;

-- Whether the account follows the model, from a year that includes p_year
-- (a listing without a year counts).
create function public.user_tracks(p_user uuid, p_motorcycle_id uuid, p_year integer)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.user_models u
                 where u.user_id = p_user
                   and u.motorcycle_id = p_motorcycle_id
                   and u.tracked
                   and (p_year is null or p_year >= u.min_year))
$$;

-- What an anonymous session follows: every collected model, from its
-- collected year.
create function public.collected(p_motorcycle_id uuid, p_year integer)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.motorcycles m
                 where m.id = p_motorcycle_id
                   and m.is_active
                   and (p_year is null or p_year >= m.min_year))
$$;

-- The caller's view (app): its own list, or everything collected for an
-- anonymous session (no claim counts as anonymous, as in require_account).
create function public.caller_tracks(p_motorcycle_id uuid, p_year integer)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
    then public.collected(p_motorcycle_id, p_year)
    else public.user_tracks(auth.uid(), p_motorcycle_id, p_year)
  end
$$;

-- A saved search's owner, for the alerts: the same rule, read from the
-- account itself (alerts are made by the collector, with no caller).
-- Security definer to read auth.users; an account asks only about itself.
create function public.owner_tracks(p_user uuid, p_motorcycle_id uuid, p_year integer)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is not null and p_user is distinct from auth.uid() then false
    when (select coalesce(u.is_anonymous, false) from auth.users u where u.id = p_user)
    then public.collected(p_motorcycle_id, p_year)
    else public.user_tracks(p_user, p_motorcycle_id, p_year)
  end
$$;

-- Computed fields for the app (PostgREST: select and filter by them).
-- motorcycles.tracked_by_me / my_min_year: the caller's choice.
create function public.tracked_by_me(m public.motorcycles)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.caller_tracks(m.id, null)
$$;

create function public.my_min_year(m public.motorcycles)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select u.min_year from public.user_models u
     where u.user_id = auth.uid() and u.motorcycle_id = m.id),
    m.min_year)
$$;

-- listings.in_my_models: a listing of one of the caller's models, from the
-- caller's year.
create function public.in_my_models(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.caller_tracks(l.motorcycle_id, l.year)
$$;

grant execute on function public.user_tracks(uuid, uuid, integer) to anon, authenticated;
grant execute on function public.collected(uuid, integer) to anon, authenticated;
grant execute on function public.caller_tracks(uuid, integer) to anon, authenticated;
-- Signed-in and anonymous sessions (role authenticated) read
-- saved_search_matches through their own saved searches.
revoke all on function public.owner_tracks(uuid, uuid, integer) from public, anon;
grant execute on function public.owner_tracks(uuid, uuid, integer) to authenticated;
grant execute on function public.tracked_by_me(public.motorcycles) to anon, authenticated;
grant execute on function public.my_min_year(public.motorcycles) to anon, authenticated;
grant execute on function public.in_my_models(public.listings) to anon, authenticated;

-- Collect the model while any account follows it, from the earliest year
-- any of them asks for. When collection starts or stops, its listings get
-- the model back or lose it (as switching a model on or off did before).
create function public.refresh_collected_model(p_motorcycle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_was boolean;
  v_now boolean;
  v_min integer;
begin
  select m.is_active into v_was
  from public.motorcycles m where m.id = p_motorcycle_id
  for update;

  select count(*) > 0, min(u.min_year) into v_now, v_min
  from public.user_models u
  where u.motorcycle_id = p_motorcycle_id and u.tracked;

  update public.motorcycles
  set is_active = v_now,
      min_year = coalesce(v_min, min_year),
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

-- Follow a model or stop: only for the caller; the collection follows.
create or replace function public.set_model_tracked(p_motorcycle_id uuid, p_tracked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  insert into public.user_models (user_id, motorcycle_id, tracked, min_year)
  select auth.uid(), m.id, p_tracked, m.min_year
  from public.motorcycles m where m.id = p_motorcycle_id
  on conflict (user_id, motorcycle_id)
  do update set tracked = excluded.tracked, updated_at = now();

  perform public.refresh_collected_model(p_motorcycle_id);
end;
$$;

-- The caller's first year; the searches ask for the earliest of all.
create or replace function public.set_model_min_year(p_motorcycle_id uuid, p_min_year integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  if p_min_year < 1990 or p_min_year > extract(year from now())::integer + 1 then
    raise exception 'Year % is out of range', p_min_year using errcode = '22023';
  end if;
  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  -- A year for a model not followed is kept for when it is.
  insert into public.user_models (user_id, motorcycle_id, tracked, min_year)
  values (auth.uid(), p_motorcycle_id, false, p_min_year)
  on conflict (user_id, motorcycle_id)
  do update set min_year = excluded.min_year, updated_at = now();

  perform public.refresh_collected_model(p_motorcycle_id);
end;
$$;

-- A model added from the app is followed by the account that added it.
create or replace function public.add_catalog_model(
  p_brand               text,
  p_model               text,
  p_min_year            integer,
  p_olx_search          text,
  p_standvirtual_search text default null,
  p_aliases             text[] default '{}',
  p_engine_cc_min       integer default null,
  p_engine_cc_max       integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_brand text := btrim(p_brand);
  v_model text := btrim(p_model);
  v_slug  text;
  v_id    uuid;
  v_range int4range := public.engine_range_from_name(v_model);
begin
  perform public.require_account();

  if v_brand = '' or v_model = '' then
    raise exception 'Brand and model are required' using errcode = '22023';
  end if;
  if nullif(btrim(p_olx_search), '') is null
     and nullif(btrim(p_standvirtual_search), '') is null then
    raise exception 'A search address is required' using errcode = '22023';
  end if;
  if p_min_year < 1990 or p_min_year > extract(year from now())::integer + 1 then
    raise exception 'Year % is out of range', p_min_year using errcode = '22023';
  end if;
  if p_engine_cc_min not between 1 and 3000
     or p_engine_cc_max not between 1 and 3000
     or p_engine_cc_min > p_engine_cc_max then
    raise exception 'Engine size range %-% is invalid',
      p_engine_cc_min, p_engine_cc_max using errcode = '22023';
  end if;

  if p_engine_cc_min is null and p_engine_cc_max is null then
    p_engine_cc_min := lower(v_range);
    p_engine_cc_max := upper(v_range) - 1;
  end if;

  v_slug := btrim(regexp_replace(lower(v_brand || '-' || v_model),
                                 '[^a-z0-9]+', '-', 'g'), '-');

  insert into public.motorcycles
    (brand, model, slug, min_year, is_active, aliases,
     olx_search, standvirtual_search, engine_cc_min, engine_cc_max)
  values
    (v_brand, v_model, v_slug, p_min_year, true,
     coalesce(p_aliases, '{}'),
     nullif(btrim(p_olx_search), ''),
     nullif(btrim(p_standvirtual_search), ''),
     p_engine_cc_min, p_engine_cc_max)
  returning id into v_id;

  insert into public.user_models (user_id, motorcycle_id, min_year)
  values (auth.uid(), v_id, p_min_year);

  return v_id;
exception
  when unique_violation then
    raise exception '% % is already in the list', v_brand, v_model
      using errcode = '23505';
end;
$$;

-- Saved searches (and so every alert built on them) only find listings of
-- their owner's models, from the owner's years.
create or replace view public.saved_search_matches
with (security_invoker = true) as
select s.id as saved_search_id, l.id as listing_id
from public.saved_searches s
join public.listings l
  on l.status in ('active', 'price_changed')
 and l.duplicate_of is null
 and public.listing_matches_search(
       l.motorcycle_id, l.year, l.price, l.mileage, l.location, l.seller_type,
       s.motorcycle_id, s.min_year, s.max_price, s.max_mileage, s.location,
       s.seller_type
     )
 and public.owner_tracks(s.user_id, l.motorcycle_id, l.year)
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras));
