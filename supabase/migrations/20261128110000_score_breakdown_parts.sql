-- N.126: the detail page shows the whole Deal Score calculation, so the
-- breakdown also keeps the two parts of the year/mileage slice: the
-- mileage score (against the bike's age) and the year score, with the
-- mileage's share. The next scoring writes them for every live listing
-- (the breakdown changes, so recalculate_deal_scores rewrites each once).
create or replace function public.combine_deal_score(
  p_price_score integer, p_mileage_score integer, p_year_score integer,
  p_risk_score integer, p_extras integer default 0,
  p_seller_score integer default null::integer,
  p_w_price numeric default 35, p_w_year_mileage numeric default 20,
  p_w_risk numeric default 10, p_w_seller numeric default 10,
  p_mileage_share numeric default 0.7, p_points_per_extra integer default 1,
  p_max_extras integer default 3, p_without_price integer default 70)
returns table(deal_score smallint, breakdown jsonb)
language sql immutable
set search_path to ''
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
      ('seller', p_w_seller, p_seller_score::numeric)
  ),
  used as (select * from slices where score is not null),
  base as (
    select
      count(*) as n,
      case when count(*) > 0 then sum(weight * score) / sum(weight) end as score,
      bool_or(name = 'price') as has_price,
      coalesce(jsonb_object_agg(name, round(score, 1)), '{}'::jsonb) as scores,
      coalesce(jsonb_object_agg(name, weight), '{}'::jsonb) as weights
    from used
  ),
  bonus as (
    select p_points_per_extra * least(greatest(coalesce(p_extras, 0), 0), p_max_extras)
             as points
  )
  select
    case when b.n = 0 then null
         else round(least(
                case when b.has_price then 100 else p_without_price end,
                b.score + x.points))::smallint
    end,
    jsonb_build_object(
      'slices_used',     b.n,
      'slices_total',    4,
      'scores',          b.scores,
      'weights',         b.weights,
      'equipment_bonus', x.points,
      'capped_without_price',
        b.n > 0 and not coalesce(b.has_price, false)
        and b.score + x.points > p_without_price
    )
    -- The year/mileage slice's parts (null ones left out).
    || jsonb_strip_nulls(jsonb_build_object(
      'mileage_score', p_mileage_score,
      'year_score',    p_year_score,
      'mileage_share',
        case when p_mileage_score is not null and p_year_score is not null
             then p_mileage_share end
    ))
  from base b, bonus x
$$;
