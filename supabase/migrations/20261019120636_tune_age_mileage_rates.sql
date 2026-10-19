-- Rates tuned on the real MT-07 market (2026-10-19, 13 listings): a fit gave
-- about 5.8 % a year and almost no mileage effect beyond age; 4 % a year and
-- 0.2 % per 1000 km leave no trend by model year in the fair values.
create or replace function public.age_mileage_factor(
  p_year_diff   integer,
  p_km_diff     integer,
  p_per_year    numeric default 0.04,
  p_per_1000km  numeric default 0.002
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select greatest(0.6, least(1.6, exp(
    p_per_year * coalesce(p_year_diff, 0)
    - p_per_1000km * coalesce(p_km_diff, 0) / 1000.0
  )))
$$;

select public.recalculate_deal_scores();