-- Saved searches can ask for equipment ("com quickshifter e malas"): the
-- codes of listing_extras (quickshifter, exhaust, luggage, heated_grips,
-- protection, new_tyres), all required. Empty means any. A listing's
-- extras are in score_breakdown->'extras', so a listing without a score
-- never matches a set criterion (as with the score criteria).
alter table public.saved_searches
  add column extras text[] not null default '{}'
    check (extras <@ array['quickshifter', 'exhaust', 'luggage',
                           'heated_grips', 'protection', 'new_tyres']);

create or replace view public.saved_search_matches
with (security_invoker = true) as
select s.id as saved_search_id, l.id as listing_id
from public.saved_searches s
join public.listings l
  on l.status in ('active', 'price_changed')
 and l.duplicate_of is null
 and public.listing_matches_search(
       l.motorcycle_id, l.year, l.price, l.mileage, l.location, l.seller_type,
       s.motorcycle_id, s.min_year, s.max_price, s.max_mileage, s.location,
       s.seller_type
     )
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras));
