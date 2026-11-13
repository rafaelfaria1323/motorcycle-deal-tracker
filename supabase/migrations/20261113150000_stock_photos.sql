-- N.78: an ad whose photos are all stock photos (each one in 5 or more other
-- ads, of at least 3 other bikes) shows nothing of the bike itself: a risk
-- reason, `stock_photos` (10). Banners and press photos were already left
-- out of the photo matches (store_photo_hashes); now an ad made only of
-- them says so. A dealer's new bike (100 km or less) is left out: a press
-- photo is normal there. "Other bikes" are told apart by year and mileage
-- (to the 1 000 km), so the same bike put up again and again with its own
-- photos never counts.

alter table public.listings
  add column stock_photos boolean not null default false;

comment on column public.listings.stock_photos is
  'Every fingerprinted photo is in 5+ other ads of 3+ other bikes (refresh_stock_photos); N.78.';

create or replace function public.refresh_stock_photos(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with per_photo as (
    select h.listing_id,
           count(distinct o.listing_id) as others,
           count(distinct (ol.year, ol.mileage / 1000))
             filter (where (ol.year, ol.mileage / 1000)
                           is distinct from (l.year, l.mileage / 1000)) as other_bikes
    from public.listing_photo_hashes h
    join public.listings l on l.id = h.listing_id
    left join public.listing_photo_hashes o
      on o.bands && h.bands
     and o.listing_id <> h.listing_id
     and bit_count((o.hash # h.hash)::bit(64)) <= 5
    left join public.listings ol on ol.id = o.listing_id
    where h.listing_id = any(p_ids)
    group by h.listing_id, h.position
  ),
  per_listing as (
    select listing_id, bool_and(others >= 5 and other_bikes >= 3) as stock
    from per_photo
    group by listing_id
  )
  update public.listings l
  set stock_photos = coalesce(p.stock, false)
  from (select unnest(p_ids) as id) ids
  left join per_listing p on p.listing_id = ids.id
  where l.id = ids.id
    and l.stock_photos is distinct from coalesce(p.stock, false);
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.refresh_stock_photos(uuid[]) from public, anon, authenticated;

-- As in 20261028170000_photo_fingerprints.sql, then the stock photos of the
-- stored listings and of every ad sharing one of their photos (a new ad can
-- make an older ad's photo a stock one).
create or replace function public.store_photo_hashes(p_listings jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
  n integer;
begin
  select coalesce(array_agg((e ->> 'id')::uuid), '{}')
  into v_ids
  from jsonb_array_elements(p_listings) e;

  delete from public.listing_photo_hashes where listing_id = any(v_ids);
  delete from public.listing_photo_matches
  where listing_id = any(v_ids) or other_id = any(v_ids);

  insert into public.listing_photo_hashes (listing_id, position, hash)
  select (e ->> 'id')::uuid, h.ord::smallint, h.value::bigint
  from jsonb_array_elements(p_listings) e
  cross join lateral jsonb_array_elements_text(e -> 'hashes') with ordinality h(value, ord)
  on conflict (listing_id, position) do nothing;

  update public.listings
  set photos_hashed_at = now()
  where id = any(v_ids);
  get diagnostics n = row_count;

  with mine as (
    select listing_id, position, hash, bands
    from public.listing_photo_hashes
    where listing_id = any(v_ids)
  ),
  near as (
    select m.listing_id, m.position, o.listing_id as other_id
    from mine m
    join public.listing_photo_hashes o
      on o.bands && m.bands
     and o.listing_id <> m.listing_id
    where bit_count((m.hash # o.hash)::bit(64)) <= 5
  ),
  common as (
    select listing_id, position
    from near
    group by listing_id, position
    having count(distinct other_id) >= 5
  ),
  photos as (
    select listing_id, count(*) as total
    from public.listing_photo_hashes
    where listing_id in (select listing_id from near)
       or listing_id in (select other_id from near)
    group by listing_id
  ),
  pairs as (
    select n.listing_id, n.other_id, count(distinct n.position)::smallint as shared
    from near n
    where not exists (
      select 1 from common c
      where c.listing_id = n.listing_id and c.position = n.position
    )
    group by n.listing_id, n.other_id
  ),
  kept as (
    select p.*
    from pairs p
    join photos a on a.listing_id = p.listing_id
    join photos b on b.listing_id = p.other_id
    where p.shared >= 2 or a.total = 1 or b.total = 1
  )
  -- Both ways round; a pair stored in this call is found from both sides.
  insert into public.listing_photo_matches (listing_id, other_id, shared)
  select a, b, max(shared)
  from (
    select listing_id as a, other_id as b, shared from kept
    union all
    select other_id, listing_id, shared from kept
  ) both_ways
  group by a, b;

  perform public.refresh_stock_photos(array(
    select unnest(v_ids)
    union
    select o.listing_id
    from public.listing_photo_hashes m
    join public.listing_photo_hashes o
      on o.bands && m.bands
     and o.listing_id <> m.listing_id
    where m.listing_id = any(v_ids)
      and bit_count((m.hash # o.hash)::bit(64)) <= 5
  ));

  return n;
end;
$$;

revoke all on function public.store_photo_hashes(jsonb) from public, anon, authenticated;


-- As in 20261112120000_fact_edits.sql, plus `stock_photos` (10).
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
    select 'stock_photos', 10
    where 'stock_photos' = any(p_text_signals)
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

-- As in 20261112120000_fact_edits.sql, plus the stock photos.
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
  || case
       when l.stock_photos
            and not (l.seller_type = 'dealer' and l.mileage <= 100)
       then array['stock_photos']
       else '{}'::text[]
     end
  || public.fact_edit_signals(l.mileage, l.mileage_from_text, l.mileage_max_seen,
                              l.year, l.year_first_seen)
) r
where l.status in ('active', 'price_changed');

-- Every ad already fingerprinted.
select public.refresh_stock_photos(array(
  select distinct listing_id from public.listing_photo_hashes));
