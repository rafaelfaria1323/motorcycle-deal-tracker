-- Official new-bike list price (EUR, Portugal) used as a comparison reference.
-- Null means "not set yet". checked_at records when the price was last verified,
-- since list prices change.
alter table public.motorcycles
  add column new_price_reference numeric(10, 2) check (new_price_reference >= 0),
  add column new_price_checked_at date;