-- A saved search (and the Ofertas filter) can ask for several models:
-- "two of the three Hondas". motorcycle_ids holds them; empty means any
-- model. The single motorcycle_id stays for app builds still open from
-- before this change: when one writes it, it replaces the list (its
-- meaning: one model, or any when null) and is cleared, so the list is
-- the only criterion the matching reads.
alter table public.saved_searches
  add column motorcycle_ids uuid[] not null default '{}';

update public.saved_searches
set motorcycle_ids = array[motorcycle_id], motorcycle_id = null
where motorcycle_id is not null;

create function public.saved_search_single_model()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' or new.motorcycle_id is not null then
    new.motorcycle_ids := case
      when new.motorcycle_id is null then '{}'::uuid[]
      else array[new.motorcycle_id]
    end;
    new.motorcycle_id := null;
  end if;
  return new;
end;
$$;

revoke all on function public.saved_search_single_model() from public, anon, authenticated;

create trigger saved_searches_single_model
before insert or update of motorcycle_id on public.saved_searches
for each row execute function public.saved_search_single_model();

create or replace view public.saved_search_matches
with (security_invoker = true) as
select s.id as saved_search_id, l.id as listing_id
from public.saved_searches s
join public.listings l
  on l.status in ('active', 'price_changed')
 and l.duplicate_of is null
 and public.listing_matches_search(
       l.motorcycle_id, l.year, l.price, l.mileage, l.location, l.seller_type,
       null, s.min_year, s.max_price, s.max_mileage, s.location,
       s.seller_type
     )
 and (cardinality(s.motorcycle_ids) = 0 or l.motorcycle_id = any(s.motorcycle_ids))
 and public.owner_tracks(s.user_id, l.motorcycle_id, l.year)
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras))
 and (not s.only_my_colours
      or public.likes_colour(s.user_id, l.motorcycle_id, l.colour));
