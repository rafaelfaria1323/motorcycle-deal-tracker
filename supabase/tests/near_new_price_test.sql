-- Nearly new bikes (N.51): 2 years or less from mid-year and at most half
-- the normal mileage, also priced against a new one; the price slice takes
-- the better of that and the market comparison.

update public.motorcycles set new_price_reference = 8250 where slug = 'yamaha-mt-07';

-- The MT-07 that started it: last year's, 691 km, 7 250 € with a new one
-- at 8 250 €, among others of its year at about 7 800 €.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.mileage, v.price, 'Lisboa', 'active'
from public.motorcycles m,
     (values
       ('near',   extract(year from current_date)::int - 1,   691, 7250),
       ('used',   extract(year from current_date)::int - 1, 12000, 7250),
       ('old',    extract(year from current_date)::int - 4,   691, 7250),
       ('nokm',   extract(year from current_date)::int - 1,  null, 7250),
       ('dmg',    extract(year from current_date)::int - 1,   691, 7250),
       ('pricey', extract(year from current_date)::int - 1,   500, 8600),
       ('c1', extract(year from current_date)::int - 1, 3000, 7800),
       ('c2', extract(year from current_date)::int - 1, 3000, 7800),
       ('c3', extract(year from current_date)::int - 1, 3000, 7800),
       ('c4', extract(year from current_date)::int - 1, 3000, 7800),
       ('c5', extract(year from current_date)::int - 1, 3000, 7800)
     ) v(sid, year, mileage, price)
where m.slug = 'yamaha-mt-07';

update public.listings
set description = 'Teve um toque por trás, precisa do suporte de matrícula.'
where source_listing_id = 'dmg';

select public.recalculate_deal_scores();

do $$
declare
  near jsonb := (select score_breakdown from public.listings where source_listing_id = 'near');
  used jsonb := (select score_breakdown from public.listings where source_listing_id = 'used');
  old jsonb := (select score_breakdown from public.listings where source_listing_id = 'old');
  nokm jsonb := (select score_breakdown from public.listings where source_listing_id = 'nokm');
  dmg jsonb := (select score_breakdown from public.listings where source_listing_id = 'dmg');
  pricey jsonb := (select score_breakdown from public.listings where source_listing_id = 'pricey');
begin
  -- 12.1 % below new: 50 + 12.1 x 2.5 = 80, above its market score.
  assert (near ->> 'new_price')::numeric = 8250, format('new price, got %s', near ->> 'new_price');
  assert (near ->> 'pct_below_new')::numeric = 12.1, format('pct below new, got %s', near ->> 'pct_below_new');
  assert (near ->> 'price_from_new')::boolean, 'priced against a new one';
  assert (near -> 'scores' ->> 'price')::numeric = 80,
    format('price slice from the new price, got %s', near -> 'scores' ->> 'price');
  assert (near -> 'scores' ->> 'price')::numeric
         > public.price_score(7250, (near ->> 'market_price')::numeric, 2.5),
    'better than the market comparison';
  -- Too many km, too old, mileage unknown or damage: market only.
  assert used ->> 'new_price' is null and not (used ->> 'price_from_new')::boolean, 'used: market only';
  assert old ->> 'new_price' is null, 'old: market only';
  assert nokm ->> 'new_price' is null, 'no mileage: market only';
  assert not (dmg ->> 'price_from_new')::boolean, 'damaged: market only';
  -- Above the price of a new one it still scores below the middle.
  assert (pricey ->> 'pct_below_new')::numeric < 0, 'above new';
  assert (pricey -> 'scores' ->> 'price')::numeric < 50,
    format('dearer than new, got %s', pricey -> 'scores' ->> 'price');
  assert (select deal_score from public.listings where source_listing_id = 'near')
         > (select deal_score from public.listings where source_listing_id = 'old'),
    'nearly new bike at the same price ranks higher';
end $$;

-- Without comparables the new price still scores the price, so the score
-- is not capped at 70.
delete from public.listings where source_listing_id <> 'near';
select public.recalculate_deal_scores();

do $$
declare
  near jsonb := (select score_breakdown from public.listings where source_listing_id = 'near');
begin
  assert (near -> 'scores' ->> 'price')::numeric = 80,
    format('scored from the new price alone, got %s', near -> 'scores' ->> 'price');
  assert (near ->> 'price_from_new')::boolean, 'flagged';
  assert not coalesce((near ->> 'capped_without_price')::boolean, false), 'not capped at 70';
end $$;

-- A new price below the market estimate (an old reference): the market
-- comparison is better and stays.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, status)
select 'olx', 'k' || g, 'https://x/k' || g, m.id, m.brand, m.model,
       extract(year from current_date)::int - 1, 3000, 7800, 'Lisboa', 'active'
from public.motorcycles m, generate_series(1, 5) g
where m.slug = 'yamaha-mt-07';
update public.motorcycles set new_price_reference = 7000 where slug = 'yamaha-mt-07';
select public.recalculate_deal_scores();

do $$
declare
  near jsonb := (select score_breakdown from public.listings where source_listing_id = 'near');
begin
  assert not (near ->> 'price_from_new')::boolean, 'market comparison kept';
  assert (near -> 'scores' ->> 'price')::numeric
         = public.price_score(7250, (near ->> 'market_price')::numeric, 2.5),
    format('market score, got %s', near -> 'scores' ->> 'price');
end $$;
