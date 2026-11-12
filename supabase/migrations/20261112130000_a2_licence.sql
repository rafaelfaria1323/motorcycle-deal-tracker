-- Bikes an A2 licence allows (N.63): 35 kW at most, or a version limited
-- to 35 kW from a bike of 70 kW at most (the A2 rule: no more than twice
-- the limit). Each model's maximum power goes in the catalog; the
-- computed field listings.a2 says whether a listing is 'ready' (a model
-- of 35 kW or less, or an ad saying it is limited to 35 kW,
-- power_version's 'a2_limited') or 'restrictable' (a model of 70 kW or
-- less, which a dealer's kit limits), null otherwise or unknown (a model
-- added from the app has no power until a migration fills it). Ofertas
-- and saved searches filter on it; it is never part of a score.
alter table public.motorcycles
  add column power_kw numeric(5,1)
    constraint motorcycles_power_kw check (power_kw > 0 and power_kw <= 250);

comment on column public.motorcycles.power_kw is
  'The model''s maximum power in kW (its current generation); the A2 licence (N.63).';

-- Makers' figures for the European versions (2026).
update public.motorcycles m
set power_kw = v.kw
from (values
  ('yamaha-mt-07',       54.0),
  ('yamaha-r7',          54.0),
  ('yamaha-tracer-7',    54.0),
  ('yamaha-r1',         147.1),
  ('yamaha-r3',          30.9),
  ('yamaha-r9',          87.5),
  ('honda-cb125r',       11.0),
  ('honda-cb300r',       22.9),
  ('honda-cbr500r',      35.0),
  ('honda-cb750-hornet', 67.5),
  ('honda-cb650r',       70.0),
  ('honda-cbr650r',      70.0),
  ('honda-cbr600rr',     89.0)
) v(slug, kw)
where m.slug = v.slug;

-- Pure: 'ready', 'restrictable' or null from the model's power and the
-- listing's text signals.
create function public.a2_fit(p_power_kw numeric, p_text_signals text[])
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when 'a2_limited' = any (coalesce(p_text_signals, '{}')) then 'ready'
    when p_power_kw <= 35 then 'ready'
    when p_power_kw <= 70 then 'restrictable'
  end
$$;

-- Computed field (listings.a2): select and filter by it. A row whose
-- text signals aren't stored yet (a migration cleared them) reads its
-- A2 version from the text: power_version, pure, callable by the API.
create function public.a2(l public.listings)
returns text
language sql
stable
set search_path = ''
as $$
  select public.a2_fit(
    (select m.power_kw from public.motorcycles m where m.id = l.motorcycle_id),
    coalesce(l.text_signals, array[public.power_version(l.variant, l.description)]))
$$;

grant execute on function public.power_version(text, text) to anon, authenticated;
grant execute on function public.a2_fit(numeric, text[]) to anon, authenticated;
grant execute on function public.a2(public.listings) to anon, authenticated;

-- A saved search's 'ready' takes only bikes ready for A2; 'restrictable'
-- takes those too.
alter table public.saved_searches
  add column a2 text check (a2 in ('ready', 'restrictable'));

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
 and (cardinality(s.motorcycle_ids) = 0 or l.motorcycle_id = any (s.motorcycle_ids))
 and public.owner_tracks(s.user_id, l.motorcycle_id, l.year)
 and (s.min_deal_score is null or l.deal_score >= s.min_deal_score)
 and (s.max_risk_score is null or l.risk_score <= s.max_risk_score)
 and (s.max_distance_km is null
      or public.distance_from_home(s.user_id, l.location) <= s.max_distance_km)
 and (cardinality(s.extras) = 0
      or coalesce(l.score_breakdown -> 'extras', '[]'::jsonb) @> to_jsonb(s.extras))
 and (not s.only_my_colours
      or public.likes_colour(s.user_id, l.motorcycle_id, l.colour))
 and (s.district is null or public.place_district(l.location) = s.district)
 and (s.max_year is null or l.year <= s.max_year)
 and (s.min_price is null or (l.price >= 300 and l.price >= s.min_price))
 and (s.a2 is null
      or public.a2(l) = 'ready'
      or (s.a2 = 'restrictable' and public.a2(l) = 'restrictable'));
