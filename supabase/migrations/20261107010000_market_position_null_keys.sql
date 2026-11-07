-- The cards' market position was null for every listing: the score
-- breakdown has carried the keys legalisation_cost, damage_allowance and
-- their percentages since N.52 (20261106120000_not_legalised.sql), set to
-- null when they don't apply, and `?` only asks whether a key exists, so
-- the legalised percentage (null) was read for every bike. Now a reference
-- counts only when its values are there.
create or replace function public.market_position(l public.listings)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when l.price >= 300
     and coalesce((l.score_breakdown ->> 'market_listing_count')::integer, 0) >= 3
    then round(
      case
        when l.score_breakdown ->> 'legalisation_cost' is not null
         and l.score_breakdown ->> 'pct_below_legalised_value' is not null
        then (l.score_breakdown ->> 'pct_below_legalised_value')::numeric
        when l.score_breakdown ->> 'damage_allowance' is not null
         and l.score_breakdown ->> 'pct_below_damaged_value' is not null
        then (l.score_breakdown ->> 'pct_below_damaged_value')::numeric
        else (l.score_breakdown ->> 'pct_below_market')::numeric
      end, 1)
  end
$$;
