-- N.62: a seller who edits the ad after it was found, lowering the km or
-- making the year newer, is a risk reason. Only changes in the seller's
-- favour count (more km or an older year is a correction against them),
-- and only the ad's own fields (not km read from the description).

alter table public.listings
  add column mileage_max_seen integer,
  add column year_first_seen smallint;

comment on column public.listings.mileage_max_seen is
  'Highest mileage the ad''s own field has shown (not read from the text); N.62.';
comment on column public.listings.year_first_seen is
  'The first year the ad showed; N.62.';

-- Fires after listings_mileage_from_text (names in order), so a mileage
-- read from the description is known as such.
create or replace function public.track_listing_facts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.mileage is not null and not coalesce(new.mileage_from_text, false) then
    new.mileage_max_seen := greatest(new.mileage_max_seen, new.mileage);
    -- greatest ignores nulls: the first value is kept as it is.
  end if;
  if new.year_first_seen is null then
    new.year_first_seen := new.year;
  end if;
  return new;
end;
$$;

revoke all on function public.track_listing_facts() from public, anon, authenticated;

create trigger listings_track_facts
before insert or update of mileage, year, mileage_from_text on public.listings
for each row execute function public.track_listing_facts();

-- The signals, from the stored facts: at least 1 000 km fewer than seen
-- before, or a newer year than the first one.
create or replace function public.fact_edit_signals(
  p_mileage integer, p_mileage_from_text boolean, p_mileage_max_seen integer,
  p_year integer, p_year_first_seen integer)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_remove(array[
    case when p_mileage is not null and not coalesce(p_mileage_from_text, false)
              and p_mileage_max_seen - p_mileage >= 1000
         then 'mileage_lowered' end,
    case when p_year > p_year_first_seen then 'year_raised' end
  ], null)
$$;

revoke all on function public.fact_edit_signals(integer, boolean, integer, integer, integer)
  from public, anon, authenticated;

-- What we know now becomes the starting point.
update public.listings
set mileage_max_seen = case when not mileage_from_text then mileage end,
    year_first_seen = year
where mileage is not null or year is not null;

create or replace function public.risk_from_signals(p_price numeric, p_market_price numeric, p_year integer, p_mileage integer, p_description text, p_location text, p_details_known boolean, p_private_seller boolean, p_registrations integer, p_service_book boolean, p_origin text, p_warranty_until date, p_relists integer, p_on_sale_since timestamp with time zone, p_text_signals text[])
returns table(risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  -- Measured against the value of the bike with its damage
  -- (damage_allowance): a damaged bike priced like one isn't suspicious.
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (m.value - p_price) / m.value * 100
    end as below
    from (select p_market_price
                 * (1 - public.damage_allowance(p_text_signals)) as value) m
  ),
  signals(code, points) as (
    select 'price_far_below_market'::text, 45 from pct where below >= 25
    union all
    select 'price_below_market', 25 from pct where below >= 15 and below < 25
    union all
    select 'possible_accident', 30
    where 'possible_accident' = any(p_text_signals)
    union all
    select 'needs_repair', 20
    where 'needs_repair' = any(p_text_signals)
    union all
    select 'cosmetic_damage', 5
    where 'cosmetic_damage' = any(p_text_signals)
    union all
    select 'photos_reused', 10
    where 'photos_reused' = any(p_text_signals)
    union all
    select 'no_mileage', 15 where p_mileage is null
    union all
    select 'no_year', 10 where p_year is null
    union all
    -- A placeholder ("0", "1", "10") on a bike three or more years old, or
    -- far more than anyone rides in a year (bikes average 3-6 000 km). The
    -- age counts from mid-year registration in days, at least one year, as
    -- expected_mileage does.
    select 'suspicious_mileage', 10
    where p_mileage is not null and p_year is not null
      and (
        (p_mileage < 100
          and p_year <= extract(year from current_date)::integer - 3)
        or p_mileage::numeric
           / greatest(1, public.decimal_year() - (p_year + 0.5))
           > 25000
      )
    union all
    -- Only meaningful once the page was read, and only for private sellers:
    -- dealers rarely write more than boilerplate.
    select 'thin_description', 10
    where p_details_known and p_private_seller
      and char_length(btrim(coalesce(p_description, ''))) < 40
    union all
    select 'no_location', 5
    where nullif(btrim(coalesce(p_location, '')), '') is null
    union all
    select 'many_owners', 15 where p_registrations >= 3
    union all
    select 'no_service_book', 10 where p_service_book = false
    union all
    -- Not yet legalised in Portugal (legalisation_status): more than
    -- imported, which it replaces.
    select v, case v when 'not_legalised_outside_eu' then 20 else 15 end
    from unnest(p_text_signals) v
    where v in ('not_legalised', 'not_legalised_outside_eu')
    union all
    select 'imported', 10 where p_origin is not null and p_origin <> 'national'
      and not coalesce(p_text_signals && array['not_legalised', 'not_legalised_outside_eu'], false)
    union all
    -- The text says something else than the ad's own fields.
    select c, 10 from unnest(public.text_contradictions(
      p_description, p_year, p_mileage, p_origin, p_service_book)) c
    union all
    -- A bike put up again after its ad went (mark_relists): it did not sell
    -- at that price. More when it happened twice or the bike has been on
    -- sale for over 90 days counting the earlier ads.
    select 'relisted_often', 10
    where p_relists >= 2
       or (p_relists = 1 and p_on_sale_since < now() - interval '90 days')
    union all
    select 'relisted', 5
    where p_relists = 1
      and (p_on_sale_since is null or p_on_sale_since >= now() - interval '90 days')
    union all
    -- An A2 (35 kW) version, still held back or unlocked (power_version).
    select v, case v when 'a2_limited' then 15 else 10 end
    from unnest(p_text_signals) v
    where v in ('a2_limited', 'a2_unlocked')
    union all
    -- The seller edited the ad after it was found, in their own favour
    -- (N.62: listings_track_facts): fewer km, or a newer year.
    select 'mileage_lowered', 15
    where 'mileage_lowered' = any(p_text_signals)
    union all
    select 'year_raised', 10
    where 'year_raised' = any(p_text_signals)
    union all
    -- The ad's field, or the text when the field is empty.
    select 'first_owner', -5
    where p_registrations = 1
       or (p_registrations is null
           and 'single_owner_in_text' = any(p_text_signals))
    union all
    select 'service_book', -5 where p_service_book
    union all
    select 'under_warranty', -10 where p_warranty_until >= current_date
  )
  select
    greatest(0, least(100, coalesce(sum(points), 0)))::smallint,
    coalesce(array_agg(code order by points desc, code), '{}'::text[])
  from signals
$$;

revoke all on function public.risk_from_signals(numeric, numeric, integer, integer, text, text, boolean, boolean, integer, boolean, text, date, integer, timestamp with time zone, text[])
  from public, anon, authenticated;

create or replace view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.listing_fair_prices f on f.listing_id = l.id
left join public.listings prev on prev.id = l.relisted_from
cross join lateral public.risk_from_signals(
  l.price,
  case when f.comparable_count >= 3 then f.fair_price end,
  l.year,
  l.mileage,
  l.description,
  l.location,
  l.details_checked_at is not null or l.source = 'olx',
  coalesce(l.seller_type::text = 'private', false),
  l.registrations,
  l.service_book,
  l.origin,
  l.warranty_until,
  (l.relisted_from is not null)::integer + (prev.relisted_from is not null)::integer,
  l.relisted_since,
  coalesce(l.text_signals, public.description_signals(l.variant, l.description))
  || case
       when exists (
         select 1
         from public.listing_photo_matches m
         join public.listings o on o.id = m.other_id
         where m.listing_id = l.id
           and o.first_seen_at < l.first_seen_at
           and (o.motorcycle_id <> l.motorcycle_id
                or (l.seller_type = 'private' and o.seller_type = 'dealer'))
       )
       then array['photos_reused']
       else '{}'::text[]
     end
  || public.fact_edit_signals(l.mileage, l.mileage_from_text, l.mileage_max_seen,
                              l.year, l.year_first_seen)
) r
where l.status in ('active', 'price_changed');
