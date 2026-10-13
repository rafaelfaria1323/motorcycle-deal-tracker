-- Used price vs new-bike reference, per listing.
-- Only listings whose model has a reference price and which have a price.
create view public.listing_new_price_comparison
with (security_invoker = true) as
select
  l.id                                              as listing_id,
  l.motorcycle_id,
  l.price                                           as used_price,
  m.new_price_reference                             as new_price,
  m.new_price_reference - l.price                   as difference,
  round((m.new_price_reference - l.price)
        / nullif(m.new_price_reference, 0) * 100, 1) as difference_pct
from public.listings l
join public.motorcycles m on m.id = l.motorcycle_id
where l.price is not null
  and m.new_price_reference is not null;