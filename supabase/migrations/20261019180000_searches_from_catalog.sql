-- The collector's searches come from the tracked models: each model names
-- the search that finds it on each site. Models that share a search
-- (Yamaha R7, R1, R3 and R9 are all under OLX "R/YZF") share one request.
-- The OLX year filter is added by the collector from the models' min_year.
alter table public.motorcycles
  add column olx_search text check (
    olx_search like 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/%'),
  add column standvirtual_search text check (
    standvirtual_search like 'https://www.standvirtual.com/motos/%');

comment on column public.motorcycles.olx_search is
  'OLX search address that lists this model, without year filter.';
comment on column public.motorcycles.standvirtual_search is
  'Standvirtual search address that lists this model.';

-- The searches the collector used until now.
update public.motorcycles set olx_search =
  'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/'
  '?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07'
where slug in ('yamaha-mt-07', 'yamaha-tracer-7');

update public.motorcycles set olx_search =
  'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/'
  '?search%5Bfilter_enum_modelo%5D%5B0%5D=r'
  '&search%5Bfilter_enum_modelo%5D%5B1%5D=yzf'
where slug in ('yamaha-r7', 'yamaha-r1', 'yamaha-r3', 'yamaha-r9');

update public.motorcycles set olx_search =
  'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/'
  '?search%5Bfilter_enum_modelo%5D%5B0%5D=cb'
  '&search%5Bfilter_enum_modelo%5D%5B1%5D=cbr'
where slug in ('honda-cb650r', 'honda-cbr650r', 'honda-cb125r',
               'honda-cb300r', 'honda-cbr500r', 'honda-cb750-hornet',
               'honda-cbr600rr');

update public.motorcycles set standvirtual_search = v.url
from (values
  ('yamaha-mt-07',  'https://www.standvirtual.com/motos/yamaha/mt-07'),
  ('yamaha-r7',     'https://www.standvirtual.com/motos/yamaha/r/q-7'),
  ('honda-cb650r',  'https://www.standvirtual.com/motos/honda/cb/q-650'),
  ('honda-cbr650r', 'https://www.standvirtual.com/motos/honda/cbr/q-650')
) v(slug, url)
where public.motorcycles.slug = v.slug;

-- The search each listing was last found by, so a run removes only listings
-- of the searches it read in full: a search that was not run (its models
-- switched off, or the request limit reached) leaves its listings alone.
alter table public.listings add column search_key text;

-- Called by the collector after each import: p_keys is
-- {"<source_listing_id>": "<search address>", ...}.
create function public.set_search_keys(p_source text, p_keys jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set search_key = k.value
  from jsonb_each_text(p_keys) k
  where l.source = p_source
    and l.source_listing_id = k.key
    and l.search_key is distinct from k.value;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.set_search_keys(text, jsonb)
  from public, anon, authenticated;

-- Removal limited to the listings of p_search_keys (plus, with
-- p_include_unkeyed, those no search has claimed yet). Without
-- p_search_keys it covers the whole source, as before.
drop function public.mark_removed_listings(text, text[], numeric);

create function public.mark_removed_listings(
  p_source           text,
  p_seen_ids         text[],
  p_max_fraction     numeric default 0.5,
  p_search_keys      text[]  default null,
  p_include_unkeyed  boolean default true
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  live_count    integer;
  missing_count integer;
begin
  if p_seen_ids is null or cardinality(p_seen_ids) = 0 then
    raise exception
      'Refusing to mark listings as removed: the import contains no listings.';
  end if;

  select count(*),
         count(*) filter (where l.source_listing_id <> all (p_seen_ids))
  into live_count, missing_count
  from public.listings l
  where l.source = p_source
    and l.status in ('active', 'price_changed')
    and (p_search_keys is null
         or l.search_key = any (p_search_keys)
         or (p_include_unkeyed and l.search_key is null));

  if live_count > 0
     and missing_count::numeric / live_count > p_max_fraction then
    raise exception
      'Refusing to remove % of % live listings (limit % percent). Check the file, or use --force.',
      missing_count, live_count, round(p_max_fraction * 100);
  end if;

  update public.listings l
  set status = 'removed',
      last_checked_at = now()
  where l.source = p_source
    and l.status in ('active', 'price_changed')
    and (p_search_keys is null
         or l.search_key = any (p_search_keys)
         or (p_include_unkeyed and l.search_key is null))
    and l.source_listing_id <> all (p_seen_ids);

  return missing_count;
end;
$$;

revoke all on function public.mark_removed_listings(text, text[], numeric, text[], boolean)
  from public, anon, authenticated;

-- ---- Changing the catalog from the app (signed-in accounts only) --------

create function public.require_account()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Sign in to change the tracked models'
      using errcode = '42501';
  end if;
end;
$$;

-- Switching a model off also drops it from its listings, so they leave the
-- scores and the market figures now rather than at their next sighting
-- (which never comes if the model's search is no longer run). Switching it
-- back on matches them again at the next collection.
create or replace function public.set_model_tracked(p_motorcycle_id uuid, p_tracked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  update public.motorcycles
  set is_active = p_tracked, updated_at = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  if not p_tracked then
    update public.listings set motorcycle_id = null
    where motorcycle_id = p_motorcycle_id;
    perform public.recalculate_deal_scores();
  end if;
end;
$$;

-- The first year tracked: older listings are rejected, and the OLX search
-- asks for this year onwards.
create function public.set_model_min_year(p_motorcycle_id uuid, p_min_year integer)
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

  update public.motorcycles
  set min_year = p_min_year, updated_at = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
end;
$$;

-- Adds a model, tracked from the next collection. The address is the site's
-- search with the brand and model filters set, copied from the browser.
create function public.add_catalog_model(
  p_brand               text,
  p_model               text,
  p_min_year            integer,
  p_olx_search          text,
  p_standvirtual_search text default null,
  p_aliases             text[] default '{}'
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

  v_slug := btrim(regexp_replace(lower(v_brand || '-' || v_model),
                                 '[^a-z0-9]+', '-', 'g'), '-');

  insert into public.motorcycles
    (brand, model, slug, min_year, is_active, aliases,
     olx_search, standvirtual_search)
  values
    (v_brand, v_model, v_slug, p_min_year, true,
     coalesce(p_aliases, '{}'),
     nullif(btrim(p_olx_search), ''),
     nullif(btrim(p_standvirtual_search), ''))
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception '% % is already in the list', v_brand, v_model
      using errcode = '23505';
end;
$$;

revoke all on function public.set_model_min_year(uuid, integer) from public, anon;
revoke all on function public.add_catalog_model(text, text, integer, text, text, text[])
  from public, anon;
grant execute on function public.set_model_min_year(uuid, integer) to authenticated;
grant execute on function public.add_catalog_model(text, text, integer, text, text, text[])
  to authenticated;
