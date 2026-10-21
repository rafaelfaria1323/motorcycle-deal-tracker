-- Ads under 300 € (parts, deposits, typos) are no comparables; they must
-- not bend the model's depreciation fit either.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, first_seen_at)
select 'olx', 'dep' || g, 'https://x/dep' || g, m.id, m.brand, m.model,
       2016 + g % 8, 10000 + (g % 5) * 3000,
       round(7000 * exp(0.04 * (g % 8) - 0.005 * (g % 5) * 3)), now()
from public.motorcycles m, generate_series(1, 40) g
where m.slug = 'yamaha-mt-07';

do $$
declare before numeric; after numeric;
begin
  select per_year into before from public.model_depreciation d
    join public.motorcycles m on m.id = d.motorcycle_id where m.slug = 'yamaha-mt-07';
  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price, first_seen_at)
  select 'olx', 'parts', 'https://x/parts', m.id, m.brand, m.model, 2016, 30000, 1, now()
  from public.motorcycles m where m.slug = 'yamaha-mt-07';
  select per_year into after from public.model_depreciation d
    join public.motorcycles m on m.id = d.motorcycle_id where m.slug = 'yamaha-mt-07';
  assert abs(after - before) < 0.002,
    format('a 1 € parts ad moved the yearly rate from %s to %s', before, after);
end $$;
