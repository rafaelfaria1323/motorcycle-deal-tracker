-- The seller slice of the Deal Score: dealers with 5 bikes or more get
-- their dealer_score, shrunk towards every such dealer's rate with the
-- weight of 5 bikes (N.134); smaller dealers and private sellers skip the
-- slice.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, seller_name, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2021, v.km, 6500, v.seller_type::public.seller_type, v.seller, 'active'
from public.motorcycles m,
     (values
       ('b1', 12000, 'dealer',  'Big Motos'),
       ('b2', 13000, 'dealer',  'big motos'),
       ('b3', 14000, 'dealer',  'Big Motos'),
       ('b4', 15000, 'dealer',  'Big Motos'),
       ('b5', null,  'dealer',  'Big Motos'),
       ('c1', 12000, 'dealer',  'Clean Motos'),
       ('c2', 13000, 'dealer',  'Clean Motos'),
       ('c3', 14000, 'dealer',  'Clean Motos'),
       ('c4', 15000, 'dealer',  'Clean Motos'),
       ('c5', 16000, 'dealer',  'Clean Motos'),
       ('s1', 12000, 'dealer',  'Small Motos'),
       ('p1', 12000, 'private', null)
     ) v(sid, km, seller_type, seller)
where m.slug = 'yamaha-mt-07';

select public.recalculate_deal_scores();

do $$
declare
  b jsonb := (select score_breakdown from public.listings where source_listing_id = 'b1');
  c jsonb := (select score_breakdown from public.listings where source_listing_id = 'c1');
  s jsonb := (select score_breakdown from public.listings where source_listing_id = 's1');
  p jsonb := (select score_breakdown from public.listings where source_listing_id = 'p1');
begin
  -- Every dealer with 5+ bikes: 0.5 problems over 10 bikes, 0.05 a bike.
  -- 5 bikes, one without mileage: 100 - 100 * (0.5 + 5 * 0.05) / 10 = 92.5.
  assert (b -> 'scores' ->> 'seller')::numeric = 93, format('big dealer, got %s', b);
  -- 5 clean bikes: 100 - 100 * (0 + 5 * 0.05) / 10 = 97.5, not 100.
  assert (c -> 'scores' ->> 'seller')::numeric = 98, format('clean dealer, got %s', c);
  assert (b ->> 'dealer_bikes')::int = 5, 'bikes counted';
  assert not (s -> 'scores') ? 'seller', 'one bike: no seller slice';
  assert not (p -> 'scores') ? 'seller', 'private seller: no seller slice';
  assert p ->> 'dealer_bikes' is null, 'no dealer';
end $$;
