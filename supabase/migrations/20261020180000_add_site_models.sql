-- The brands and models each site offers in its search filters, read by
-- the collector from the search pages it already fetches (no extra
-- requests). The app's "Adicionar modelo" picks from them and builds the
-- searches from the sites' own ids.
create table public.site_models (
  source     text not null check (source in ('standvirtual', 'olx')),
  make_id    text not null,
  make_name  text not null,
  model_id   text not null,
  model_name text not null,
  -- Ads the site has for the model (Standvirtual only).
  ads        integer check (ads >= 0),
  seen_at    timestamptz not null default now(),
  primary key (source, make_id, model_id)
);

comment on table public.site_models is
  'Brands and models in the sites'' search filters (ids go into search addresses).';

-- Readable by everyone, like the catalog; only the collector (service
-- role) writes.
alter table public.site_models enable row level security;

create policy "Site models are readable by everyone"
  on public.site_models
  for select
  to anon, authenticated
  using (true);

grant select on public.site_models to anon, authenticated;

-- The picker's brand list: Standvirtual has every brand's models.
create view public.site_makes
with (security_invoker = true) as
select make_id, make_name, coalesce(sum(ads), 0)::integer as ads
from public.site_models
where source = 'standvirtual'
group by make_id, make_name;

grant select on public.site_makes to anon, authenticated;

-- add_catalog_model also takes the engine size range, so "Forza 350" is
-- told apart from the Forza 125 (see ModelResolver). Calls without the new
-- arguments behave as before.
drop function public.add_catalog_model(text, text, integer, text, text, text[]);

create function public.add_catalog_model(
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

revoke all on function public.add_catalog_model(
  text, text, integer, text, text, text[], integer, integer
) from public, anon;
grant execute on function public.add_catalog_model(
  text, text, integer, text, text, text[], integer, integer
) to authenticated;
