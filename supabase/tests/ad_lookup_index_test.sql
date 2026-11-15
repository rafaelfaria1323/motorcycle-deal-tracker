-- B.5 (20261115230000_ad_lookup_index.sql): an ad is looked up through
-- the index, and a valuation is ready only with 5 ads it can use.
insert into public.listings (source, source_listing_id, url, brand, model, year, mileage, price)
select 'olx', 'al' || g, 'https://www.olx.pt/d/anuncio/mota-IDal' || g || '.html',
       'Yamaha', 'MT-07', 2020, 10000, 6000
from generate_series(1, 2000) g;
analyze public.listings;

do $$
declare
  v_plan text := '';
  v_line text;
begin
  set local enable_seqscan = off;
  for v_line in
    explain select l.id from public.listings l
    where l.source = 'olx'
      and substring(l.url from '-(ID[0-9A-Za-z]+)\.html') = 'IDal7'
  loop
    v_plan := v_plan || v_line || E'\n';
  end loop;
  assert v_plan like '%listings_ad_code%', format('the index is used: %s', v_plan);
  assert public.listing_for_ad('https://www.olx.pt/d/anuncio/mota-IDal7.html')
         = (select id from public.listings where source_listing_id = 'al7'),
    'the ad is found';
end $$;

-- Readiness: 5 near ads, 4 of them without a mileage.
insert into public.collector_runs (started_at, status)
values (now() - interval '1 hour', 'ok');
update public.motorcycles
set collected_since = now() - interval '2 days', min_year = 2024, is_active = true
where slug = 'honda-cb650r';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'ak' || g, 'https://x/ak' || g, m.id, m.brand, m.model,
       2025, case when g = 1 then 1000 end, 8000
from public.motorcycles m, generate_series(1, 5) g
where m.slug = 'honda-cb650r';

do $$
declare
  v_cb uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
begin
  assert public.near_comparable_count(v_cb, 2026) = 5, 'five without a mileage asked';
  assert public.near_comparable_count(v_cb, 2026, 3000) = 1, 'one with a mileage';
  assert public.bike_value_ready(v_cb, 2026), 'no mileage: ready';
  assert not public.bike_value_ready(v_cb, 2026, 3000),
    'with a mileage, bike_value would have one comparable: waits';
  assert (select comparable_count from public.bike_value(v_cb, 2026, 3000)) = 1,
    'the same count as bike_value';
end $$;
