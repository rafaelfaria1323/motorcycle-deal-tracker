-- N.108 (20261115150000_year_ranges.sql): a last year per followed model,
-- and a year range for a value's comparables.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', false);

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'yr-' || v.year || '-' || g, 'https://x/yr-' || v.year || '-' || g,
       m.id, m.brand, m.model, v.year, 20000, v.price + g * 100
from public.motorcycles m,
     (values (2018, 5000), (2021, 7000), (2024, 9000)) v(year, price),
     generate_series(1, 5) g
where m.slug = 'yamaha-mt-07';

-- The comparables' year range.
do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  plain record;
  same record;
  v record;
  t record;
begin
  -- No range: as bike_value, which now calls it.
  select * into plain from public.bike_value(mt07, 2021, 20000);
  select * into same from public.bike_value_in_years(mt07, 2021, 20000, null, null);
  assert plain.comparable_count = same.comparable_count
         and plain.fair_price = same.fair_price, 'no range: the tiers as before';

  -- Only 2018: five ads, each brought to 2021 at the model's rate.
  select * into v from public.bike_value_in_years(mt07, 2021, 20000, 2018, 2018);
  assert v.comparable_count = 5, format('five 2018 ads, got %s', v.comparable_count);
  assert v.fair_price > 5300, format('adjusted up from 5300, got %s', v.fair_price);

  -- From 2018 to 2024: all fifteen, though five near ones exist.
  select * into v from public.bike_value_in_years(mt07, 2021, 20000, 2018, 2024);
  assert v.comparable_count = 15, format('all fifteen, got %s', v.comparable_count);

  -- Only a first year.
  select * into v from public.bike_value_in_years(mt07, 2021, 20000, 2021, null);
  assert v.comparable_count = 10, format('2021 and 2024, got %s', v.comparable_count);

  -- A range without ads: no estimate.
  select * into v from public.bike_value_in_years(mt07, 2021, 20000, 2010, 2012);
  assert v.comparable_count = 0 and v.fair_price is null, 'no ads in the range';

  -- The typed ad's scores use the range too.
  select * into t from public.typed_ad_score(mt07, 2021, 20000, 7300, true,
    p_from_year => 2018, p_to_year => 2018);
  assert (t.breakdown ->> 'market_listing_count')::int = 5,
    format('typed ad: five comparables, got %s', t.breakdown ->> 'market_listing_count');
  select * into t from public.typed_ad_score(mt07, 2021, 20000, 7300, true);
  assert (t.breakdown ->> 'market_price')::numeric = plain.fair_price,
    'typed ad without a range: bike_value''s estimate';
end $$;

-- The last year of a followed model.
set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
do $$
declare
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  failed boolean;
begin
  perform public.set_model_tracked(mt07, true);
  perform public.set_model_years(mt07, 2018, 2021);
  assert (select public.my_min_year(m) = 2018 and public.my_max_year(m) = 2021
          from public.motorcycles m where id = mt07), 'the account''s years';
  assert (select array_agg(distinct year::int order by year::int)
          from public.listings l where public.in_my_models(l)) = array[2018, 2021],
    'only the years in the range';

  -- No last year again: every year from the first.
  perform public.set_model_years(mt07, 2021, null);
  assert (select array_agg(distinct year::int order by year::int)
          from public.listings l where public.in_my_models(l)) = array[2021, 2024],
    'from the first year on';

  -- A last year before the first is refused.
  begin
    perform public.set_model_years(mt07, 2021, 2019);
    failed := false;
  exception when sqlstate '22023' then
    failed := true;
  end;
  assert failed, 'last year before the first refused';

  -- The old first-year call keeps a last year it doesn't pass.
  perform public.set_model_years(mt07, 2018, 2022);
  perform public.set_model_min_year(mt07, 2020);
  assert (select public.my_max_year(m) = 2022 from public.motorcycles m where id = mt07),
    'last year kept';
  -- ... and drops one the new first year passes.
  perform public.set_model_min_year(mt07, 2023);
  assert (select public.my_min_year(m) = 2023 and public.my_max_year(m) is null
          from public.motorcycles m where id = mt07), 'last year dropped';
end $$;
