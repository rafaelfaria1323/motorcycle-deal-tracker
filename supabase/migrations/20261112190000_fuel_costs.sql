-- Fuel in the cost of ownership (N.74): each model's consumption and the
-- national average price of petrol, so the app's "Custo de ter esta mota"
-- adds what the kilometres a year cost at the pump.

-- The maker's WMTC figure (litres per 100 km; null unknown: the app
-- estimates one by engine size). Read by everyone with the catalog.
alter table public.motorcycles
  add column fuel_l_per_100km numeric(3, 1)
    constraint motorcycles_fuel_consumption
      check (fuel_l_per_100km between 1 and 15);

comment on column public.motorcycles.fuel_l_per_100km is
  'The maker''s WMTC consumption, litres per 100 km; null unknown.';

-- The makers' European spec sheets (WMTC, 2026 models).
update public.motorcycles m
set fuel_l_per_100km = v.litres
from (values
  ('yamaha-mt-07',       4.2),
  ('yamaha-r7',          4.2),
  ('yamaha-tracer-7',    4.3),
  ('yamaha-r1',          7.2),
  ('yamaha-r3',          3.8),
  ('yamaha-r9',          5.0),
  ('honda-cb125r',       2.1),
  ('honda-cb300r',       3.0),
  ('honda-cbr500r',      3.6),
  ('honda-cb750-hornet', 4.3),
  ('honda-cb650r',       4.9),
  ('honda-cbr650r',      4.9),
  ('honda-cbr600rr',     6.0)
) v(slug, litres)
where m.slug = v.slug;

-- The national average price per litre and day, as DGEG publishes it
-- (precoscombustiveis.dgeg.gov.pt, public, no key): `fuel` is our code,
-- 'petrol_95' = DGEG's "Gasolina simples 95" (id 3201). Readable by
-- everyone; written only by refresh_fuel_prices().
create table public.fuel_prices (
  fuel       text not null check (fuel in ('petrol_95')),
  day        date not null,
  price      numeric(5, 3) not null check (price > 0 and price < 10),
  stations   integer check (stations >= 0),
  fetched_at timestamptz not null default now(),
  primary key (fuel, day)
);

alter table public.fuel_prices enable row level security;

create policy "Fuel prices are readable by everyone"
  on public.fuel_prices
  for select
  to anon, authenticated
  using (true);

-- DGEG writes prices as text: "1,911 €". Null when it isn't one.
create function public.fuel_price_from_text(p_text text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_text ~ '^\s*[0-9]+([.,][0-9]+)?\s*(€)?\s*$'
    then replace(regexp_replace(p_text, '[^0-9,.]', '', 'g'), ',', '.')::numeric
  end
$$;
revoke all on function public.fuel_price_from_text(text) from public, anon, authenticated;

-- Reads the last week's daily averages of petrol 95 from DGEG (one
-- request) and keeps them; rows over 400 days old go. Returns the days
-- stored, or null when DGEG could not be read (the app keeps showing the
-- last price it has, with its date).
create function public.refresh_fuel_prices()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_response extensions.http_response;
  v_count    integer;
begin
  begin
    perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '20000');
    v_response := extensions.http((
      'GET',
      'https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PMD'
        || '?idsTiposComb=3201'
        || '&dataIni=' || to_char(current_date - 7, 'YYYY-MM-DD')
        || '&dataFim=' || to_char(current_date, 'YYYY-MM-DD')
        || '&qtdPorPagina=10&pagina=1&orderDesc=1',
      array[extensions.http_header('Accept', 'application/json'),
            extensions.http_header('User-Agent',
              'MotorcycleDealTracker/0.1 (personal project, low volume)')],
      null,
      null
    )::extensions.http_request);
  exception when others then
    raise warning 'Fuel prices not read: %', sqlerrm;
    return null;
  end;

  if v_response.status <> 200 then
    raise warning 'Fuel prices not read: HTTP %', v_response.status;
    return null;
  end if;

  begin
    insert into public.fuel_prices (fuel, day, price, stations)
    select 'petrol_95', r.day, r.price, r.stations
    from (
      select (e ->> 'Data')::date as day,
             public.fuel_price_from_text(e ->> 'PrecoMedio') as price,
             case when e ->> 'NumPostos' ~ '^[0-9]+$'
                  then (e ->> 'NumPostos')::integer end as stations
      from jsonb_array_elements(
             case when jsonb_typeof(v_response.content::jsonb -> 'resultado') = 'array'
                  then v_response.content::jsonb -> 'resultado'
                  else '[]'::jsonb end) e
    ) r
    where r.day is not null and r.price > 0 and r.price < 10
    on conflict (fuel, day) do update
      set price = excluded.price,
          stations = excluded.stations,
          fetched_at = now();
    get diagnostics v_count = row_count;
  exception when others then
    raise warning 'Fuel prices not understood: %', sqlerrm;
    return null;
  end;

  delete from public.fuel_prices where day < current_date - 400;
  return v_count;
end;
$$;
revoke all on function public.refresh_fuel_prices() from public, anon, authenticated;

-- Once a day, after DGEG's overnight update.
select cron.schedule(
  'refresh-fuel-prices',
  '41 9 * * *',
  $job$ select public.refresh_fuel_prices() $job$
);
