-- "Quanto vale a minha mota" (20261028150000_bike_value.sql): the same
-- comparables as a listing's fair price, for a bike that isn't listed.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'bv' || g, 'https://x/bv' || g, m.id, m.brand, m.model,
       2020, 20000, 6000 + g * 100
from public.motorcycles m, generate_series(1, 5) g
where m.slug = 'yamaha-mt-07';
-- Left out: an old bike (5 near ones exist), a 1 € ad, a duplicate, a
-- removed ad, one without mileage, another model.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, v.price, v.status::public.listing_status
from public.motorcycles m,
     (values ('bv-old', 2010, 20000, 2000, 'active'),
             ('bv-parts', 2020, 20000, 1, 'active'),
             ('bv-gone', 2020, 20000, 9000, 'removed'),
             ('bv-nokm', 2020, null, 9000, 'active')) v(sid, year, km, price, status)
where m.slug = 'yamaha-mt-07';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, duplicate_of)
select 'olx', 'bv-dup', 'https://x/bv-dup', m.id, m.brand, m.model, 2020, 20000, 9000,
       (select id from public.listings where source_listing_id = 'bv1')
from public.motorcycles m where m.slug = 'yamaha-mt-07';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'bv-r7', 'https://x/bv-r7', m.id, m.brand, m.model, 2020, 20000, 9000
from public.motorcycles m where m.slug = 'yamaha-r7';

do $$
declare
  v record;
  rate numeric;
begin
  select * into v from public.bike_value(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'), 2020, 20000);
  assert v.comparable_count = 5, format('five comparables, got %s', v.comparable_count);
  assert v.fair_price = 6300, format('median 6300, got %s', v.fair_price);
  assert v.low_price = 6200 and v.high_price = 6400,
    format('middle half 6200-6400, got %s-%s', v.low_price, v.high_price);

  -- A year newer, at the same mileage: worth the model's yearly rate more.
  select per_year into rate from public.model_depreciation
  where motorcycle_id = (select id from public.motorcycles where slug = 'yamaha-mt-07');
  select * into v from public.bike_value(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'), 2021, 20000);
  assert v.fair_price = round(6300 * exp(coalesce(rate, 0.04)), 2),
    format('a year newer: %s', v.fair_price);

  -- Without a mileage the one without mileage counts too, unadjusted for km.
  select * into v from public.bike_value(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'), 2020);
  assert v.comparable_count = 6, format('six without a mileage, got %s', v.comparable_count);

  -- A model without ads: no estimate.
  select * into v from public.bike_value(
    (select id from public.motorcycles where slug = 'honda-cb650r'), 2020, 20000);
  assert v.comparable_count = 0 and v.fair_price is null, 'no comparables, no estimate';
end $$;

do $$
begin
  assert has_function_privilege('anon', 'public.bike_value(uuid, integer, integer)', 'execute'),
    'visitors can value a bike';
  assert has_function_privilege('authenticated', 'public.bike_value(uuid, integer, integer)', 'execute'),
    'accounts can value a bike';
end $$;
