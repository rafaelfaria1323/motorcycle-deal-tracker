-- A model named with its engine size ("Forza 350", "ADV 350") but added
-- without one had no engine limits, so the ModelResolver could never pick
-- it by engine size: Standvirtual ads named only "Forza" or "ADV" (with
-- 330 cc in the ad) stayed unmatched. The size in the name now counts
-- as the engine size, 10 % either way (the app's engineRange).

-- The engine range named by a model ("Forza 350" -> [315, 386)): a number
-- of 50 to 2500 at the end of the name; null otherwise ("MT-07", "R7").
create function public.engine_range_from_name(p_model text)
returns int4range
language sql
immutable
set search_path = ''
as $$
  select case when n between 50 and 2500
              then int4range(round(n * 0.9)::integer, round(n * 1.1)::integer, '[]')
         end
  from (select (regexp_match(btrim(p_model), '(?:^|\s)(\d{2,4})\s*(?:cc)?$', 'i'))[1]::integer as n) x;
$$;

revoke all on function public.engine_range_from_name(text)
  from public, anon, authenticated;

update public.motorcycles m
set engine_cc_min = lower(public.engine_range_from_name(m.model)),
    engine_cc_max = upper(public.engine_range_from_name(m.model)) - 1
where m.engine_cc_min is null
  and m.engine_cc_max is null
  and public.engine_range_from_name(m.model) is not null;

-- Models added from now on get the same.
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

  return v_id;
exception
  when unique_violation then
    raise exception '% % is already in the list', v_brand, v_model
      using errcode = '23505';
end;
$$;

