-- F.7 (feature review 1.8): the cards say how far the asking price is from
-- the estimated value ("8 % abaixo do valor estimado"), the reason most
-- people open an ad.
--
-- listings.market_position is that percentage (positive = below the
-- estimate), as the listing page's explanation reads it: against the
-- damaged value when the text tells of an accident or a repair, nothing
-- below 3 comparables (the price is not scored then) or for a placeholder
-- price. A computed field, so a list asks for one number, never the score
-- breakdown.

create function public.market_position(l public.listings)
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
        when l.score_breakdown ? 'damage_allowance'
         and l.score_breakdown ? 'damaged_value'
        then (l.score_breakdown ->> 'pct_below_damaged_value')::numeric
        else (l.score_breakdown ->> 'pct_below_market')::numeric
      end, 1)
  end
$$;

grant execute on function public.market_position(public.listings) to anon, authenticated;

-- A card field, on by default: every account's saved choice gets it too
-- (they chose before it existed).
alter table public.listing_card_preferences
  drop constraint listing_card_preferences_known_fields;

alter table public.listing_card_preferences
  add constraint listing_card_preferences_known_fields check (
    visible_fields <@ array[
      'source', 'deal_score', 'price_change', 'market_position', 'year',
      'mileage', 'location', 'preferred_colour', 'risk_score', 'seller_type',
      'first_seen_at', 'colour', 'registrations', 'service_book', 'origin',
      'warranty_until', 'dealer_warranty_months', 'seller_name',
      'published_at', 'site_refreshed_at', 'status'
    ]::text[]
    and coalesce(array_ndims(visible_fields), 1) = 1
  );

alter table public.listing_card_preferences
  alter column visible_fields set default array[
    'source', 'deal_score', 'price_change', 'market_position', 'year',
    'mileage', 'location', 'preferred_colour'
  ];

update public.listing_card_preferences
set visible_fields = visible_fields || 'market_position'::text
where not visible_fields @> array['market_position'];
