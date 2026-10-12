-- Mock data for development. Safe to re-run: it replaces all 'mock' rows.
delete from public.listings where source = 'mock';  -- price history cascades

insert into public.listings
  (source, source_listing_id, url, motorcycle_id, brand, model, year, mileage,
   price, seller_type, seller_name, location, description, status, first_seen_at)
select
  v.source, v.source_listing_id, v.url, m.id, m.brand, m.model, v.year, v.mileage,
  v.price, v.seller_type::public.seller_type, v.seller_name, v.location,
  v.description, v.status::public.listing_status, now() - v.age
from (values
  -- Yamaha R7
  ('mock','r7-001','https://example.com/mock/r7-001','yamaha-r7',2026, 3500, 9300,'dealer','Moto Lisboa','Lisboa','R7 2026, one owner, warranty remaining.','price_changed', interval '21 days'),
  ('mock','r7-002','https://example.com/mock/r7-002','yamaha-r7',2026, 1200, 9850,'private','João M.','Porto','Like new, garage kept, full service history.','active', interval '6 days'),
  ('mock','r7-003','https://example.com/mock/r7-003','yamaha-r7',2026,12000, 8900,'private','Pedro S.','Braga','Some cosmetic wear, new tyres.','active', interval '34 days'),
  -- Yamaha MT-07
  ('mock','mt07-001','https://example.com/mock/mt07-001','yamaha-mt-07',2026, 1100, 7850,'dealer','Yamaha Porto','Porto','MT-07 2026, delivery mileage, 3 years warranty.','active', interval '9 days'),
  ('mock','mt07-002','https://example.com/mock/mt07-002','yamaha-mt-07',2026, 6800, 7400,'private','Ana R.','Coimbra','Second owner, accessories included.','price_changed', interval '27 days'),
  ('mock','mt07-003','https://example.com/mock/mt07-003','yamaha-mt-07',2026, 2400, 8190,'dealer','Moto Center Faro','Faro','Demo bike, A2 compatible.','active', interval '3 days'),
  -- Honda CB650R
  ('mock','cb650r-001','https://example.com/mock/cb650r-001','honda-cb650r',2025, 4000, 8250,'dealer','Honda Aveiro','Aveiro','2025 E-Clutch version, one owner.','active', interval '14 days'),
  ('mock','cb650r-002','https://example.com/mock/cb650r-002','honda-cb650r',2025, 9500, 7600,'private','Rui T.','Lisboa','Well kept, full Honda service record.','active', interval '41 days'),
  ('mock','cb650r-003','https://example.com/mock/cb650r-003','honda-cb650r',2026,  800, 9100,'dealer','Moto Setúbal','Setúbal','Registered 2026, practically new.','active', interval '5 days'),
  -- Honda CBR650R
  ('mock','cbr650r-001','https://example.com/mock/cbr650r-001','honda-cbr650r',2025, 5200, 8700,'private','Miguel C.','Porto','Quickshifter, tail tidy fitted.','active', interval '12 days'),
  ('mock','cbr650r-002','https://example.com/mock/cbr650r-002','honda-cbr650r',2025, 2100, 9300,'dealer','Honda Braga','Braga','Warranty until 2028.','price_changed', interval '18 days'),
  ('mock','cbr650r-003','https://example.com/mock/cbr650r-003','honda-cbr650r',2025,15500, 7900,'private','Sofia L.','Lisboa','Higher mileage, price negotiable.','removed', interval '52 days')
) as v(source, source_listing_id, url, slug, year, mileage, price, seller_type,
       seller_name, location, description, status, age)
join public.motorcycles m on m.slug = v.slug;

-- Price history: the three price_changed listings get a visible timeline;
-- every other listing gets a single row with its current price.
insert into public.listing_price_history (listing_id, price, observed_at)
select l.id, h.price, l.first_seen_at + h.after
from public.listings l
join (values
  ('r7-001',  9700, interval '0 days'),
  ('r7-001',  9500, interval '7 days'),
  ('r7-001',  9300, interval '14 days'),
  ('mt07-002',7900, interval '0 days'),
  ('mt07-002',7650, interval '10 days'),
  ('mt07-002',7400, interval '20 days'),
  ('cbr650r-002',9700, interval '0 days'),
  ('cbr650r-002',9500, interval '8 days'),
  ('cbr650r-002',9300, interval '15 days')
) as h(source_listing_id, price, after) on h.source_listing_id = l.source_listing_id
where l.source = 'mock';

insert into public.listing_price_history (listing_id, price, observed_at)
select l.id, l.price, l.first_seen_at
from public.listings l
where l.source = 'mock'
  and not exists (
    select 1 from public.listing_price_history h where h.listing_id = l.id
  );

-- Placeholder scores until the deal engine exists (Sprint 4).
-- cbr650r-003 is left null on purpose, to test "unscored" sorting.
update public.listings l
set deal_score = s.score
from (values
  ('r7-001', 94), ('mt07-001', 91), ('cb650r-001', 87), ('mt07-002', 83),
  ('cbr650r-001', 80), ('r7-003', 78), ('cb650r-002', 74), ('r7-002', 72),
  ('cb650r-003', 69), ('mt07-003', 66), ('cbr650r-002', 58)
) as s(source_listing_id, score)
where l.source = 'mock' and l.source_listing_id = s.source_listing_id;