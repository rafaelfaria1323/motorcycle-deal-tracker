-- Source filters are preferred; missing filters use a model-specific word
-- search. Never invent a site's model id or fall back to the whole market.
create function public.catalog_search_url(p_source text, p_brand text, p_model text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_prefix text;
  v_brand text := normalize(btrim(p_brand), NFC);
  v_model text := normalize(btrim(p_model), NFC);
  v_brand_key text := regexp_replace(lower(v_brand), '[^[:alnum:]]', '', 'g');
  v_model_key text := regexp_replace(lower(v_model), '[^[:alnum:]]', '', 'g');
  v_make_id text;
  v_model_id text;
  v_words text;
begin
  v_prefix := case p_source
    when 'olx' then 'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/'
    when 'standvirtual' then 'https://www.standvirtual.com/motos/'
  end;
  if v_prefix is null then
    raise exception 'Unsupported source %', p_source using errcode = '22023';
  end if;
  if nullif(v_brand_key, '') is null or nullif(v_model_key, '') is null then
    raise exception 'Brand and model must contain letters or numbers'
      using errcode = '22023';
  end if;

  select s.make_id, s.model_id into v_make_id, v_model_id
  from public.site_models s
  where s.source = p_source
    and regexp_replace(lower(normalize(s.make_name, NFC)), '[^[:alnum:]]', '', 'g') = v_brand_key
    and regexp_replace(lower(normalize(s.model_name, NFC)), '[^[:alnum:]]', '', 'g') = v_model_key
    and s.make_id ~* '^[a-z0-9][a-z0-9_-]*$'
    and s.model_id ~* '^[a-z0-9][a-z0-9_-]*$'
  order by s.make_id, s.model_id
  limit 1;

  if v_model_id is not null then
    if p_source = 'olx' then
      return v_prefix || v_make_id || '/'
        || '?search%5Bfilter_enum_modelo%5D%5B0%5D=' || v_model_id;
    end if;
    return v_prefix || v_make_id || '/' || v_model_id;
  end if;

  select s.make_id into v_make_id
  from public.site_models s
  where s.source = p_source
    and regexp_replace(lower(normalize(s.make_name, NFC)), '[^[:alnum:]]', '', 'g') = v_brand_key
    and s.make_id ~* '^[a-z0-9][a-z0-9_-]*$'
  order by s.make_id
  limit 1;

  -- OLX matches any query word: do not repeat the brand when its filter
  -- already restricts the search, or every bike of that brand matches.
  v_words := btrim(regexp_replace(
    lower(case when v_make_id is null then v_brand || ' ' || v_model else v_model end),
    '[^[:alnum:]]+', '-', 'g'), '-');
  return v_prefix || coalesce(v_make_id || '/', '') || 'q-' || v_words
    || case when p_source = 'olx' then '/' else '' end;
end;
$$;

revoke all on function public.catalog_search_url(text, text, text)
  from public, anon, authenticated;

create function public.ensure_model_searches()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.olx_search := coalesce(nullif(btrim(new.olx_search), ''),
    public.catalog_search_url('olx', new.brand, new.model));
  new.standvirtual_search := coalesce(nullif(btrim(new.standvirtual_search), ''),
    public.catalog_search_url('standvirtual', new.brand, new.model));
  return new;
end;
$$;

revoke all on function public.ensure_model_searches()
  from public, anon, authenticated;

create trigger motorcycles_ensure_searches
before insert or update of brand, model, olx_search, standvirtual_search
on public.motorcycles
for each row execute function public.ensure_model_searches();

-- Backfill through the same trigger, keeping every existing address.
update public.motorcycles
set olx_search = olx_search, standvirtual_search = standvirtual_search
where nullif(btrim(olx_search), '') is null
   or nullif(btrim(standvirtual_search), '') is null;

alter table public.motorcycles
  add constraint motorcycles_both_source_searches
  check (olx_search is not null and standvirtual_search is not null) not valid;
alter table public.motorcycles
  validate constraint motorcycles_both_source_searches;

-- Keep the old RPC signature and optional filter hints for older clients.
create or replace function public.add_catalog_model(
  p_brand               text,
  p_model               text,
  p_min_year            integer,
  p_olx_search           text default null,
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

revoke all on function public.add_catalog_model(
  text, text, integer, text, text, text[], integer, integer
) from public, anon, authenticated;
grant execute on function public.add_catalog_model(
  text, text, integer, text, text, text[], integer, integer
) to authenticated;
