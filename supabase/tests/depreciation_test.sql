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

-- The yearly rate is fitted given the mileage rate actually used. Here
-- prices fall 8 % a year and 0.1 % per 1000 km, older bikes have about
-- 5 000 km a year more, and the mileage rate is raised to its 0.5 % floor:
-- the joint fit's 8 % would count the age that the extra 0.4 % per
-- 1000 km already takes off again (about 2 % a year).
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, first_seen_at)
select 'olx', 'fit' || g, 'https://x/fit' || g, m.id, m.brand, m.model,
       2016 + g % 8, (8 - g % 8) * 5000 + (g % 3) * 2000,
       round(7000 * exp(0.08 * (g % 8) - 0.001 * ((8 - g % 8) * 5 + (g % 3) * 2))), now()
from public.motorcycles m, generate_series(1, 40) g
where m.slug = 'honda-cb650r';

do $$
declare d record;
begin
  select * into d from public.model_depreciation
  where motorcycle_id = (select id from public.motorcycles where slug = 'honda-cb650r');
  assert d.is_fitted and d.sample_count = 40, 'fitted on 40 ads';
  assert d.per_1000km = 0.005, format('the mileage floor, got %s', d.per_1000km);
  -- Refit given 0.5 %: about 6 %, blended 40:30 with 4 % = about 5.1 %
  -- (the joint fit's 8 % would blend to 6.3 %).
  assert d.per_year between 0.048 and 0.054,
    format('yearly rate given the mileage rate, got %s', d.per_year);
end $$;
