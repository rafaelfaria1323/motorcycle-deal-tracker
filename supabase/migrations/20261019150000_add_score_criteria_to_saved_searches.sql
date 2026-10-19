-- Saved searches (and the dashboard filters they come from) can ask for a
-- minimum Deal Score and a maximum Risk Score. Null means "any"; a set
-- criterion never matches a listing that has no score.
alter table public.saved_searches
  add column min_deal_score smallint check (min_deal_score between 0 and 100),
  add column max_risk_score smallint check (max_risk_score between 0 and 100);

-- Same view as before plus the two score criteria. Every alert type reads
-- its matches from here, so they all follow the new criteria.
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
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score);
