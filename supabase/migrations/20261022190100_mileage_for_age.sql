-- Mileage judged against the bike's age (Rafael, 2026-10-20): 20 000 km
-- is a lot for a 2-year-old bike and little for a 10-year-old one, but the
-- old score was a flat line from 0 km (100) to 20 000 km (0). Motorcycles
-- in Europe cover about 3 000-6 000 km a year (cars 10-12 000), so the
-- normal is 5 000 km a year (also the owner's default in Custo de ter esta
-- mota). Keep in step with the app's mileage_text.dart.

-- The normal mileage for a bike of p_year: 5 000 km per year of age, from
-- mid-year registration (a 2024 bike in 2026 is 2.5 years old), and never
-- less than one year's (a bike of this year: 5 000 km).
create function public.expected_mileage(
  p_year           integer,
  p_km_per_year    integer default 5000,
  p_reference_year integer default date_part('year', current_date)::integer
)
returns integer
language sql
stable
set search_path = ''
as $$
  select case when p_year is null then null
              else round(greatest(p_reference_year - p_year + 0.5, 1) * p_km_per_year)::integer
         end
$$;

-- 100 up to half the normal mileage, 75 at the normal, 50 at 1.5 times it,
-- 0 from 2.5 times it (straight lines in between). Without a year, the old
-- flat score.
create function public.mileage_use_score(
  p_mileage        integer,
  p_year           integer,
  p_km_per_year    integer default 5000,
  p_reference_year integer default date_part('year', current_date)::integer
)
returns smallint
language sql
stable
set search_path = ''
as $$
  select case
    when p_mileage is null or p_mileage < 0 then null
    when p_year is null then public.mileage_score(p_mileage)
    else (select greatest(0, least(100, round(case
                when r <= 0.5 then 100
                when r <= 1.5 then 100 - (r - 0.5) * 50
                else 50 - (r - 1.5) * 50
              end)))::smallint
          from (select p_mileage::numeric
                       / public.expected_mileage(p_year, p_km_per_year, p_reference_year) as r) x)
  end
$$;

revoke all on function public.expected_mileage(integer, integer, integer)
  from public, anon, authenticated;
revoke all on function public.mileage_use_score(integer, integer, integer, integer)
  from public, anon, authenticated;

create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with scored as (
    select
      l.id,
      ps.price_score,
      ps.market_price,
      ps.pct_below_market,
      ps.listing_count,
      public.mileage_use_score(l.mileage, l.year) as m_score,
      public.year_score(l.year)       as y_score,
      rs.risk_score,
      rs.reasons,
      public.listing_extras(l.variant, l.description) as extras
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
  ),
  combined as (
    select
      s.id,
      s.risk_score,
      c.deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras)
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      public.equipment_score(s.extras)
    ) c
  )
  update public.listings l
  set deal_score      = c.deal_score,
      risk_score      = c.risk_score,
      score_breakdown = c.breakdown,
      scored_at       = now()
  from combined c
  where l.id = c.id;

  get diagnostics n = row_count;

  update public.listings
  set deal_score = null, risk_score = null,
      score_breakdown = null, scored_at = null
  where (status not in ('active', 'price_changed')
         or duplicate_of is not null
         or motorcycle_id is null)
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;

-- The new mileage and the new extras count at once, not at the next run.
select public.recalculate_deal_scores();
