-- Deal Score's version/equipment slice (weight 15): extras the seller lists
-- in the variant or description. Found extras make the slice 70-100; none
-- found leaves it out (descriptions rarely list everything, so silence is
-- not a penalty).

-- Extras named in the text, as codes. Pure, testable with literals.
-- "sem X" ("sem top case") is removed first.
create function public.listing_extras(p_variant text, p_description text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             lower(coalesce(p_variant, '') || ' ' || coalesce(p_description, '')),
             '\msem\s+(o\s+|a\s+|os\s+|as\s+)?\w+', ' ', 'g'
           ) as text
  ),
  rules(code, pattern) as (
    values
      ('quickshifter', 'quick\s*-?\s*shift'),
      ('exhaust',
        '(akrapovi|termignoni|sc[\s-]?project|yoshimura|leovince|\mmivv\M|\marrow\M'
        '|escape\s+(desportivo|racing|completo|de\s+competi))'),
      ('luggage', '(top\s*-?\s*case|malas?\s+laterais|alforges|\mba[uú]\M)'),
      ('heated_grips', 'punhos\s+aquecidos'),
      ('protection',
        '(crash\s*-?\s*pads?|\msliders?\M|prote[cç][cç]?[aã]o\s+d[eo]\s+(motor|quadro|c[aá]rter)'
        '|protetor(es)?\s+d[eo]\s+(motor|quadro|c[aá]rter))'),
      ('new_tyres', 'pneus?\s+novos?')
  )
  select coalesce(array_agg(r.code order by r.code), '{}'::text[])
  from rules r, t
  where t.text ~ r.pattern
$$;

-- The slice's score: 70 for one extra, +10 for each more, at most 100.
create function public.equipment_score(p_extras text[])
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when cardinality(p_extras) > 0
              then least(100, 60 + 10 * cardinality(p_extras)) end
$$;

drop function public.combine_deal_score(
  integer, integer, integer, integer, numeric, numeric, numeric, numeric
);

-- Pure combiner: weighted average of the slices that have data.
-- Seller/confidence 10 and market behaviour 10 have no data yet.
create function public.combine_deal_score(
  p_price_score     integer,
  p_mileage_score   integer,
  p_year_score      integer,
  p_risk_score      integer,
  p_equipment_score integer default null,
  p_w_price         numeric default 35,
  p_w_year_mileage  numeric default 20,
  p_w_risk          numeric default 10,
  p_w_equipment     numeric default 15,
  p_mileage_share   numeric default 0.7
)
returns table (deal_score smallint, breakdown jsonb)
language sql
immutable
set search_path = ''
as $$
  with slices(name, weight, score) as (
    values
      ('price', p_w_price, p_price_score::numeric),
      ('year_mileage', p_w_year_mileage,
        case
          when p_mileage_score is not null and p_year_score is not null
            then p_mileage_share * p_mileage_score
               + (1 - p_mileage_share) * p_year_score
          else coalesce(p_mileage_score, p_year_score)::numeric
        end),
      ('risk', p_w_risk,
        case when p_risk_score is null then null else 100 - p_risk_score end::numeric),
      ('equipment', p_w_equipment, p_equipment_score::numeric)
  ),
  used as (select * from slices where score is not null)
  select
    case when count(*) = 0 then null
         else round(sum(weight * score) / sum(weight))::smallint end,
    jsonb_build_object(
      'slices_used',  count(*),
      'slices_total', 6,
      'scores',  coalesce(jsonb_object_agg(name, round(score, 1)), '{}'::jsonb),
      'weights', coalesce(jsonb_object_agg(name, weight), '{}'::jsonb)
    )
  from used
$$;

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
      public.mileage_score(l.mileage) as m_score,
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

select public.recalculate_deal_scores();
