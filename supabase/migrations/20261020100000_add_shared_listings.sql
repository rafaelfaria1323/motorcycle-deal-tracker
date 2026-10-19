-- Listings the owner saves from sites the collector does not read
-- (Facebook Marketplace, CustoJusto, any other), through the app's
-- "Adicionar anúncio" page or the iPhone share button. Nothing is fetched:
-- the owner types or shares what the ad shows. The listing is stored with
-- the catalog's brand and model names (like a collected one), scored at
-- once, and never removed by the collector, which reads only its own
-- sites. Sellers' names are never stored.
create function public.add_shared_listing(
  p_source            text,
  p_source_listing_id text,
  p_url               text,
  p_motorcycle_id     uuid,
  p_price             numeric,
  p_year              integer default null,
  p_mileage           integer default null,
  p_location          text default null,
  p_seller_type       text default 'unknown',
  p_description       text default null,
  p_images            text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  m  public.motorcycles;
  id uuid;
begin
  perform public.require_account();

  if p_source not in ('facebook', 'custojusto', 'other') then
    raise exception 'Unknown source %', p_source using errcode = '22023';
  end if;
  if nullif(trim(p_source_listing_id), '') is null
     or p_url !~* '^https://' then
    raise exception 'The link must start with https://' using errcode = '22023';
  end if;
  if p_price is null or p_price <= 0 then
    raise exception 'The price must be greater than 0' using errcode = '22023';
  end if;
  if p_year is not null
     and (p_year < 1980 or p_year > extract(year from now())::integer + 1) then
    raise exception 'Year % is out of range', p_year using errcode = '22023';
  end if;
  if p_mileage is not null and (p_mileage < 0 or p_mileage > 500000) then
    raise exception 'Mileage % is out of range', p_mileage using errcode = '22023';
  end if;

  select * into m from public.motorcycles where motorcycles.id = p_motorcycle_id;
  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  insert into public.listings as l (
    source, source_listing_id, url, motorcycle_id, brand, model, year,
    mileage, price, seller_type, location, description, images,
    details_checked_at
  ) values (
    p_source, trim(p_source_listing_id), p_url, m.id, m.brand, m.model,
    p_year, p_mileage, p_price,
    coalesce(nullif(p_seller_type, ''), 'unknown')::public.seller_type,
    nullif(trim(p_location), ''), nullif(trim(p_description), ''),
    coalesce(p_images, '{}'), now()
  )
  -- Saving the same ad again updates it (a new price adds a history row
  -- through the price trigger) and brings it back if it was removed.
  on conflict (source, source_listing_id) do update
  set url           = excluded.url,
      motorcycle_id = excluded.motorcycle_id,
      brand         = excluded.brand,
      model         = excluded.model,
      year          = excluded.year,
      mileage       = excluded.mileage,
      price         = excluded.price,
      seller_type   = excluded.seller_type,
      location      = excluded.location,
      description   = coalesce(excluded.description, l.description),
      images        = case when cardinality(excluded.images) > 0
                           then excluded.images else l.images end,
      status        = case when l.status in ('removed', 'sold')
                           then 'active'::public.listing_status
                           else l.status end,
      last_seen_at    = now(),
      last_checked_at = now(),
      updated_at      = now()
  returning l.id into id;

  perform public.recalculate_deal_scores();
  return id;
end;
$$;

revoke all on function public.add_shared_listing(
  text, text, text, uuid, numeric, integer, integer, text, text, text, text[]
) from public, anon;
grant execute on function public.add_shared_listing(
  text, text, text, uuid, numeric, integer, integer, text, text, text, text[]
) to authenticated;
