-- Main dashboard query: one model, live listings, sorted by price.
create index listings_active_model_price_idx
  on public.listings (motorcycle_id, price)
  where status in ('active', 'price_changed');

-- Single-column indexes for the other filters and sorts.
create index listings_year_idx    on public.listings (year);
create index listings_mileage_idx on public.listings (mileage);
create index listings_price_idx   on public.listings (price);
create index listings_status_idx  on public.listings (status);