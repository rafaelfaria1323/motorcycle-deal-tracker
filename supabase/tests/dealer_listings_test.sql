-- A dealer's page (N.72): the dealer's ads on both sites, whatever the
-- spelling of its name, live first, without repeats or other sellers.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, seller_name, status,
                             first_seen_at, last_seen_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2021, 9000, 6500, v.seller_type::public.seller_type, v.seller,
       v.status::public.listing_status, now() - v.first_age, now() - v.last_age
from public.motorcycles m,
     (values
       ('olx',          'live-old', 'dealer',  'Motos Lda',   'active',        interval '30 days', interval '0 days'),
       ('standvirtual', 'live-new', 'dealer',  ' MOTOS LDA ', 'price_changed', interval '2 days',  interval '0 days'),
       ('olx',          'gone-old', 'dealer',  'motos lda',   'removed',       interval '90 days', interval '60 days'),
       ('standvirtual', 'gone-new', 'dealer',  'Motos Lda',   'removed',       interval '40 days', interval '10 days'),
       ('olx',          'repeat',   'dealer',  'Motos Lda',   'active',        interval '1 day',   interval '0 days'),
       ('olx',          'other',    'dealer',  'Outro Stand', 'active',        interval '1 day',   interval '0 days'),
       ('olx',          'private',  'private', null,          'active',        interval '1 day',   interval '0 days')
     ) v(source, sid, seller_type, seller, status, first_age, last_age)
where m.slug = 'yamaha-mt-07';

update public.listings d set duplicate_of = o.id
from public.listings o
where d.source_listing_id = 'repeat' and o.source_listing_id = 'live-old';

do $$
declare
  ids text[];
begin
  select array_agg(d.source_listing_id order by d.ordinality) into ids
  from public.dealer_listings('  motos LDA') with ordinality d;
  assert ids = array['live-new', 'live-old', 'gone-new', 'gone-old'],
    format('live newest first, then gone last seen first, got %s', ids);

  assert (select count(*) from public.dealer_listings('Motos Lda', 1)) = 1,
    'the limit applies';
  assert (select count(*) from public.dealer_listings('Motos Lda', 0)) = 1,
    'at least one';
  assert (select count(*) from public.dealer_listings('', 10)) = 0,
    'no name, no ads';
  assert (select count(*) from public.dealer_listings(null, 10)) = 0,
    'null name, no ads';
  assert (select count(*) from public.dealer_listings('Desconhecido')) = 0,
    'an unknown dealer has none';
  -- The same dealer the figures count.
  assert (select bikes from public.dealer_reliability where dealer_key = 'motos lda')
       = (select count(*) from public.dealer_listings('Motos Lda')),
    'as many ads as the dealer figures count';
end $$;

-- Readable by visitors, like the listings and the dealer figures.
set local role anon;
do $$
begin
  assert (select count(*) from public.dealer_listings('Motos Lda')) = 4, 'anon reads it';
end $$;
reset role;
