-- Mileage component of the Deal Score (0-100): 100 at 0 km, 0 at p_max_km or more.
create function public.mileage_score(
  p_mileage integer,
  p_max_km  integer default 20000
)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_mileage is null or p_mileage < 0 or p_max_km <= 0 then null
    else greatest(0, least(100, round(
      100 * (1 - p_mileage::numeric / p_max_km)
    )))::smallint
  end
$$;