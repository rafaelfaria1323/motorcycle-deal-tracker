-- "Saíram do mercado por" (20261101180000_exit_prices.sql): the median
-- last price of a model's ads gone in the last 90 days, adjusted to a
-- year and mileage as bike_value is.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, last_seen_at)
select 'olx', 'ex' || g, 'https://x/ex' || g, m.id, m.brand, m.model,
       2020, 20000, 6000 + g * 100, 'removed', now() - interval '10 days'
from public.motorcycles m, generate_series(1, 5) g
where m.slug = 'yamaha-mt-07';
-- Left out: a live ad, one gone 120 days ago, a 1 € ad, one relisted
-- since, another model.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, last_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2020, 20000, v.price, v.status::public.listing_status,
       now() - make_interval(days => v.days)
from public.motorcycles m,
     (values ('ex-live', 9000, 'active', 0),
             ('ex-old', 9000, 'sold', 120),
             ('ex-parts', 1, 'removed', 5),
             ('ex-back', 9000, 'removed', 30)) v(sid, price, status, days)
where m.slug = 'yamaha-mt-07';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, relisted_from)
select 'olx', 'ex-relist', 'https://x/ex-relist', m.id, m.brand, m.model, 2020, 20000,
       9000, (select id from public.listings where source_listing_id = 'ex-back')
from public.motorcycles m where m.slug = 'yamaha-mt-07';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status)
select 'olx', 'ex-r7', 'https://x/ex-r7', m.id, m.brand, m.model, 2020, 20000, 9000,
       'removed'
from public.motorcycles m where m.slug = 'yamaha-r7';
-- A gone duplicate of a gone ad.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, duplicate_of)
select 'standvirtual', 'ex-dup', 'https://x/ex-dup', m.id, m.brand, m.model, 2020,
       20000, 9000, 'removed', (select id from public.listings where source_listing_id = 'ex1')
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v record;
  rate numeric;
begin
  select * into v from public.exit_price(mt07, 2020, 20000);
  assert v.gone_count = 5, format('five gone, got %s', v.gone_count);
  assert v.median_price = 6300, format('median 6300, got %s', v.median_price);

  -- A year newer: the model's yearly rate more.
  select per_year into rate from public.model_depreciation where motorcycle_id = mt07;
  select * into v from public.exit_price(mt07, 2021, 20000);
  assert v.median_price = round(6300 * exp(coalesce(rate, 0.04)), 2),
    format('a year newer: %s', v.median_price);

  -- The ad being looked at is left out, and so is the one it repeats.
  select * into v from public.exit_price(mt07, 2020, 20000,
    (select id from public.listings where source_listing_id = 'ex-dup'));
  assert v.gone_count = 4, format('ex1 left out, got %s', v.gone_count);
  select * into v from public.exit_price(mt07, 2020, 20000,
    (select id from public.listings where source_listing_id = 'ex5'));
  assert v.gone_count = 4 and v.median_price = 6250,
    format('ex5 left out, got %s at %s', v.gone_count, v.median_price);

  -- A model with nothing gone.
  select * into v from public.exit_price(
    (select id from public.motorcycles where slug = 'honda-cb650r'), 2020, 20000);
  assert v.gone_count = 0 and v.median_price is null, 'nothing gone, no price';
end $$;

do $$
begin
  assert has_function_privilege('anon', 'public.exit_price(uuid, integer, integer, uuid)', 'execute'),
    'visitors can read it';
  assert has_function_privilege('authenticated', 'public.exit_price(uuid, integer, integer, uuid)', 'execute'),
    'accounts can read it';
end $$;
