-- Year component of the Deal Score (0-100): 100 for the current model year,
-- minus p_points_per_year for each year of age. Future years score 100.
-- "stable", not "immutable": the default reference year reads today's date.
create function public.year_score(
  p_year              integer,
  p_reference_year    integer default date_part('year', current_date)::integer,
  p_points_per_year   integer default 10
)
returns smallint
language sql
stable
set search_path = ''
as $$
  select case
    when p_year is null then null
    else greatest(0, least(100,
      100 - (p_reference_year - p_year) * p_points_per_year
    ))::smallint
  end
$$;