-- Dealer reliability: figures per dealer name (case and spaces ignored,
-- across sites), never for private sellers.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, seller_name, status,
                             first_seen_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2021, v.km, v.price, v.seller_type::public.seller_type, v.seller, v.status::public.listing_status,
       now() - v.age
from public.motorcycles m,
     (values
       ('olx',          'a1', 12000, 6500, 'dealer',  'Motos Lda',    'active',  interval '30 days'),
       ('standvirtual', 'a2', null,  7000, 'dealer',  ' MOTOS LDA ',  'removed', interval '60 days'),
       ('olx',          'a3', 8000,  6000, 'dealer',  'motos lda',    'active',  interval '5 days'),
       -- a repeat of a1 on the same site, and of a3 on the other site
       ('olx',          'a4', 12000, 6500, 'dealer',  'Motos Lda',    'active',  interval '4 days'),
       ('standvirtual', 'a5', 8000,  6000, 'dealer',  'Motos Lda',    'active',  interval '3 days'),
       -- a new bike in stock twice: not a repeat that counts
       ('olx',          'a6', 0,     9000, 'dealer',  'Motos Lda',    'active',  interval '2 days'),
       ('olx',          'a7', 0,     9000, 'dealer',  'Motos Lda',    'active',  interval '2 days'),
       ('olx',          'p1', 9000,  5000, 'private', null,           'active',  interval '1 day'),
       ('olx',          'e1', 9000,  5000, 'dealer',  '  ',           'active',  interval '1 day')
     ) v(source, sid, km, price, seller_type, seller, status, age)
where m.slug = 'yamaha-mt-07';

update public.listings d set duplicate_of = o.id
from public.listings o
where (d.source_listing_id, o.source_listing_id) in (('a4', 'a1'), ('a5', 'a3'), ('a7', 'a6'));

-- a1 was relisted from a2; a3's price dropped; a1 had a sharp step.
update public.listings set relisted_from = (select id from public.listings where source_listing_id = 'a2')
where source_listing_id = 'a1';
update public.listings set initial_price = 6400 where source_listing_id = 'a3';
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 650, now() - interval '20 days' from public.listings where source_listing_id = 'a1';
insert into public.listing_price_history (listing_id, price, observed_at)
select id, 6500, now() - interval '10 days' from public.listings where source_listing_id = 'a1';

do $$
declare
  r public.dealer_reliability;
begin
  assert (select count(*) from public.dealer_reliability) = 1,
    'one dealer: spelling ignored, private sellers and blank names left out';

  select * into r from public.dealer_reliability;
  assert r.dealer_key = 'motos lda', r.dealer_key;
  assert r.seller_name = 'Motos Lda', format('the usual spelling, got %s', r.seller_name);
  assert r.bikes = 4, format('a1 a2 a3 a6, got %s', r.bikes);
  assert r.live = 3, format('live bikes, got %s', r.live);
  assert r.relisted = 1, format('relisted, got %s', r.relisted);
  assert r.sharp_changes = 1, format('sharp changes, got %s', r.sharp_changes);
  assert r.missing_mileage = 1, format('missing mileage, got %s', r.missing_mileage);
  assert r.repeated = 1, format('only the used bike on the same site, got %s', r.repeated);
  assert r.dropped = 1, format('dropped, got %s', r.dropped);
  assert r.first_seen_at = now() - interval '60 days', 'first seen';
end $$;

-- Readable by visitors, like the listings it comes from.
set local role anon;
do $$
begin
  assert (select count(*) from public.dealer_reliability) = 1, 'anon reads it';
end $$;
reset role;
