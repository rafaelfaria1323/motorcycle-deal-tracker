-- Versions in the fair value (N.136): each model's learnt price difference
-- per version, the comparables brought to the listing's version, a bike of
-- one's own valued as the plain version, a typed ad at its own.

-- CB650R: 8 E-Clutch ads at 8 800 and 8 plain ones at 8 000, all 2024 with
-- 3 000 km; 5 older plain ones (2019) outside the E-Clutch's years.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             variant, year, mileage, price, location, status)
select 'olx', v.sid || g, 'https://x/' || v.sid || g, m.id, m.brand, m.model,
       v.variant, v.year, v.mileage, v.price, 'Porto', 'active'
from public.motorcycles m,
     (values ('ec', 'CB650R E-Clutch', 2024, 3000, 8800, 8),
             ('plain', 'CB650R', 2024, 3000, 8000, 8),
             ('old', 'CB650R', 2019, 20000, 6000, 5)) v(sid, variant, year, mileage, price, n),
     generate_series(1, v.n) g
where m.slug = 'honda-cb650r';

-- MT-07: only 4 A2-limited ads, too few to learn from.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             variant, year, mileage, price, location, status)
select 'olx', v.sid || g, 'https://x/' || v.sid || g, m.id, m.brand, m.model,
       v.variant, 2022, 10000, v.price, 'Lisboa', 'active'
from public.motorcycles m,
     (values ('a2', 'MT-07 versão A2 35 kW', 5500, 4),
             ('full', 'MT-07', 6500, 8)) v(sid, variant, price, n),
     generate_series(1, v.n) g
where m.slug = 'yamaha-mt-07';

do $$
declare
  cb uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
  mt uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  p record;
begin
  assert public.listing_is_e_clutch(array['quickshifter', 'e_clutch']);
  assert not public.listing_is_e_clutch(null);
  assert public.listing_is_a2_limited(array['a2_limited']);
  assert not public.listing_is_a2_limited(array['a2_unlocked']);

  select * into p from public.model_version_premiums
  where motorcycle_id = cb and version = 'e_clutch';
  assert p.with_count = 8, format('E-Clutch ads, got %s', p.with_count);
  -- Only the plain ads of the E-Clutch's years count.
  assert p.without_count = 8, format('plain ads in its years, got %s', p.without_count);
  -- ln(8800 / 8000) = 0.0953, shrunk by 8 / 13.
  assert p.premium between 0.058 and 0.059, format('premium, got %s', p.premium);

  assert not exists (select 1 from public.model_version_premiums
                     where motorcycle_id = cb and version = 'a2_limited'),
    'no A2 version on the CB650R';
  assert not exists (select 1 from public.model_version_premiums where motorcycle_id = mt),
    'below 5 A2 ads nothing is learnt';
end $$;

-- The fair value: an E-Clutch ad against plain ones brought up to its
-- version, a plain ad against E-Clutch ones brought down to its own.
do $$
declare
  ec record;
  plain record;
  a2 record;
begin
  select f.* into ec from public.listing_fair_prices f
  join public.listings l on l.id = f.listing_id where l.source_listing_id = 'ec1';
  select f.* into plain from public.listing_fair_prices f
  join public.listings l on l.id = f.listing_id where l.source_listing_id = 'plain1';
  select f.* into a2 from public.listing_fair_prices f
  join public.listings l on l.id = f.listing_id where l.source_listing_id = 'a21';

  -- 7 E-Clutch at 8 800 and 8 plain at 8 000 x 1.0605: the median 8 484
  -- (it was 8 000).
  assert ec.fair_price between 8480 and 8490, format('E-Clutch fair price, got %s', ec.fair_price);
  assert ec.version_premiums = '[{"version": "e_clutch", "pct": 6.0, "ads": 8}]'::jsonb,
    format('note, got %s', ec.version_premiums);
  -- 7 plain at 8 000 and 8 E-Clutch at 8 800 / 1.0605: the median 8 298
  -- (it was 8 800).
  assert plain.fair_price between 8290 and 8300, format('plain fair price, got %s', plain.fair_price);
  assert plain.version_premiums is null, format('no note for a plain ad, got %s', plain.version_premiums);
  -- Nothing learnt: as before, and no note.
  assert a2.fair_price = 6500, format('A2 ad unchanged, got %s', a2.fair_price);
  assert a2.version_premiums is null, format('no A2 note, got %s', a2.version_premiums);
end $$;

-- A bike of one's own is valued as the plain version; a typed ad that names
-- the E-Clutch gets its premium back, with the note.
do $$
declare
  cb uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
  v record;
  typed_ec record;
  typed_plain record;
begin
  select * into v from public.bike_value(cb, 2024, 3000);
  -- 8 at 8 000 and 8 at 8 800 / 1.0605 = 8 298: the median 8 149 (it was 8 400).
  assert v.fair_price between 8145 and 8155, format('plain value, got %s', v.fair_price);

  select * into typed_ec from public.typed_ad_score(
    cb, 2024, 3000, 8500, true, p_variant => 'Honda CB650R E-Clutch');
  select * into typed_plain from public.typed_ad_score(
    cb, 2024, 3000, 8500, true, p_variant => 'Honda CB650R');
  assert (typed_plain.breakdown ->> 'market_price')::numeric = v.fair_price,
    format('typed plain ad, got %s', typed_plain.breakdown -> 'market_price');
  assert (typed_ec.breakdown ->> 'market_price')::numeric between 8640 and 8650,
    format('typed E-Clutch ad, got %s', typed_ec.breakdown -> 'market_price');
  assert typed_ec.breakdown -> 'version_premiums' -> 0 ->> 'version' = 'e_clutch',
    format('typed note, got %s', typed_ec.breakdown -> 'version_premiums');
  assert typed_plain.breakdown -> 'version_premiums' = 'null'::jsonb,
    format('no typed note, got %s', typed_plain.breakdown -> 'version_premiums');
  -- 8 500 is below the E-Clutch's value and above the plain one's.
  assert typed_ec.deal_score > typed_plain.deal_score,
    format('the same price is a better deal on the E-Clutch: %s vs %s',
           typed_ec.deal_score, typed_plain.deal_score);
end $$;

-- The run keeps the note and scores against the version's value.
do $$
declare
  ec record;
  plain record;
begin
  perform public.recalculate_deal_scores();
  select score_breakdown b into ec from public.listings where source_listing_id = 'ec1';
  select score_breakdown b into plain from public.listings where source_listing_id = 'plain1';
  assert ec.b -> 'version_premiums' -> 0 ->> 'version' = 'e_clutch',
    format('stored note, got %s', ec.b -> 'version_premiums');
  assert (ec.b ->> 'market_price')::numeric between 8480 and 8490,
    format('stored estimate, got %s', ec.b -> 'market_price');
  assert plain.b -> 'version_premiums' = 'null'::jsonb,
    format('no stored note, got %s', plain.b -> 'version_premiums');
  -- 8 800 is 3.7 % above the E-Clutch's value (10 % above the plain ads'
  -- 8 000 before); 8 000 is 3.6 % below the plain one's (9 % below 8 800).
  assert (ec.b ->> 'pct_below_market')::numeric between -4 and -3
     and (plain.b ->> 'pct_below_market')::numeric between 3 and 4,
    format('positions %s and %s', ec.b -> 'pct_below_market', plain.b -> 'pct_below_market');
end $$;
