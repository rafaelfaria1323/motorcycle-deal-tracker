-- Photo fingerprints (P.1): the collector downloads the first 3 photos of
-- each live listing once (bin/photos.dart, from the photo CDN only, after
-- the run is recorded) and stores a 64-bit difference hash (dHash) of each.
-- Listings sharing photos are stronger evidence of a duplicate or a relist
-- than their text, and photos taken from an ad of another model or a
-- dealer's are a risk reason. No AI: the same photo resized or recompressed
-- keeps nearly every bit of its hash.

alter table public.listings
  add column photos_hashed_at timestamptz;

comment on column public.listings.photos_hashed_at is
  'When the first photos were fingerprinted (listing_photo_hashes); null: not yet.';

-- One row per photo. `bands` splits the hash into 8 bytes, each tagged with
-- its place (place x 256 + byte), so a GIN index finds the hashes sharing a
-- byte: two hashes within 7 bits share at least one (pigeonhole).
create table public.listing_photo_hashes (
  listing_id uuid not null references public.listings (id) on delete cascade,
  position   smallint not null,
  hash       bigint not null,
  bands      integer[] not null generated always as (array[
    (hash & 255)::integer,
    256 + ((hash >> 8) & 255)::integer,
    512 + ((hash >> 16) & 255)::integer,
    768 + ((hash >> 24) & 255)::integer,
    1024 + ((hash >> 32) & 255)::integer,
    1280 + ((hash >> 40) & 255)::integer,
    1536 + ((hash >> 48) & 255)::integer,
    1792 + ((hash >> 56) & 255)::integer
  ]) stored,
  primary key (listing_id, position)
);

create index listing_photo_hashes_bands on public.listing_photo_hashes using gin (bands);

alter table public.listing_photo_hashes enable row level security;
revoke all on public.listing_photo_hashes from anon, authenticated;

comment on table public.listing_photo_hashes is
  'dHash of the first photos of a listing (bin/photos.dart); the collector only.';

-- Listings that share photos, both ways round; `shared` = how many of the
-- listing's photos the other has.
create table public.listing_photo_matches (
  listing_id uuid not null references public.listings (id) on delete cascade,
  other_id   uuid not null references public.listings (id) on delete cascade,
  shared     smallint not null,
  primary key (listing_id, other_id)
);

create index listing_photo_matches_other on public.listing_photo_matches (other_id);

alter table public.listing_photo_matches enable row level security;
revoke all on public.listing_photo_matches from anon, authenticated;

comment on table public.listing_photo_matches is
  'Listings sharing photos (store_photo_hashes); the collector only.';

-- Live listings of followed models whose photos were not fingerprinted
-- yet, newest first, with their first p_photos addresses. Standvirtual's
-- search pages give one thumbnail: its listings wait for their listing
-- page (photos_read_at), or for it to fail.
create function public.listings_missing_photo_hashes(
  p_limit  integer default 200,
  p_photos integer default 3
)
returns table (id uuid, images text[])
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.images[1:p_photos]
  from public.listings l
  join public.motorcycles m on m.id = l.motorcycle_id and m.is_active
  where l.status in ('active', 'price_changed')
    and l.photos_hashed_at is null
    and cardinality(l.images) > 0
    and (l.source <> 'standvirtual'
         or l.photos_read_at is not null
         or l.details_failed_at is not null)
  order by l.duplicate_of is null desc, l.first_seen_at desc, l.id
  limit p_limit
$$;

revoke all on function public.listings_missing_photo_hashes(integer, integer)
  from public, anon, authenticated;

-- Stores the hashes of each listing in p_listings ([{id, hashes: ["123",
-- ...]}], decimal text: JSON numbers would lose bits) and records which
-- listings share its photos. Two photos are the same within 5 bits. A photo
-- found in 5 or more other listings is a banner or a stock photo and
-- proves nothing; two listings share photos when they have 2 in common, or
-- 1 when either has only one photo. Returns how many listings were stored.
create function public.store_photo_hashes(p_listings jsonb)
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

  return n;
end;
$$;

revoke all on function public.store_photo_hashes(jsonb)
  from public, anon, authenticated;

-- As in 20261024110000_data_fixes.sql, with the photos' evidence: two ads
-- of the same model and year sharing photos are the same bike when their
-- mileages agree (within 1 000 km, or one unknown), as sure as a duplicate
-- can be (100), whatever their text says.
create or replace function public.mark_duplicates(p_threshold integer default 70)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set duplicate_of = null, duplicate_score = null
  where status in ('active', 'price_changed')
    and (duplicate_of is not null or duplicate_score is not null);
  with live as (
    select * from public.listings
    where status in ('active', 'price_changed')
  ),
  pairs as (
    select
      b.id as dup_id,
      a.id as original_id,
      a.first_seen_at as original_seen,
      case
        when coalesce(abs(a.mileage - b.mileage) <= 1000, true)
         and exists (select 1 from public.listing_photo_matches m
                     where m.listing_id = a.id and m.other_id = b.id)
          then 100
        else public.duplicate_similarity(
          a.mileage, b.mileage, a.price, b.price, a.location, b.location,
          a.description, b.description, a.seller_name, b.seller_name
        )
      end as score
    from live a
    join live b
      on a.motorcycle_id = b.motorcycle_id
     and a.year = b.year
     and (a.first_seen_at, a.id) < (b.first_seen_at, b.id)
    -- a dealer's identical new bikes are separate stock, not duplicates
    where not (a.source = b.source
               and coalesce(a.mileage, 0) < 500
               and coalesce(b.mileage, 0) < 500)
  ),
  best as (
    select distinct on (dup_id) dup_id, original_id, score
    from pairs
    where score >= p_threshold
    order by dup_id, original_seen, original_id
  )
  update public.listings l
  set duplicate_of = best.original_id,
      duplicate_score = best.score
  from best
  where l.id = best.dup_id;

  get diagnostics n = row_count;

  -- Chains: if C duplicates B and B duplicates A, C should point at A.
  for i in 1..5 loop
    update public.listings c
    set duplicate_of = p.duplicate_of
    from public.listings p
    where c.duplicate_of = p.id and p.duplicate_of is not null;
    exit when not found;
  end loop;

  perform public.mark_relists(p_threshold);

  return n;
end;
$$;

-- As in 20261020150000_add_relisted_listings.sql, with the photos' evidence.
create or replace function public.mark_relists(
  p_threshold    integer default 70,
  p_max_gap_days integer default 90
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set relisted_from = null, relisted_since = null, relisted_price = null
  where status in ('active', 'price_changed')
    and relisted_from is not null;

  with pairs as (
    select distinct on (b.id)
      b.id,
      a.id as previous_id,
      coalesce(
        a.relisted_since,
        least(a.published_at, a.first_seen_at)
      ) as since,
      a.price
    from public.listings b
    join public.listings a
      on a.motorcycle_id = b.motorcycle_id
     and a.year = b.year
     and a.status in ('removed', 'sold')
     and a.last_seen_at <= b.first_seen_at
     and a.last_seen_at > b.first_seen_at - make_interval(days => p_max_gap_days)
    where b.status in ('active', 'price_changed')
      -- a dealer's identical new bikes are separate stock
      and not (a.source = b.source
               and coalesce(a.mileage, 0) < 500
               and coalesce(b.mileage, 0) < 500)
      and ((coalesce(abs(a.mileage - b.mileage) <= 1000, true)
            and exists (select 1 from public.listing_photo_matches m
                        where m.listing_id = a.id and m.other_id = b.id))
           or public.duplicate_similarity(
                a.mileage, b.mileage, a.price, b.price, a.location, b.location,
                a.description, b.description, a.seller_name, b.seller_name
              ) >= p_threshold)
    order by b.id, a.last_seen_at desc, a.id
  )
  update public.listings l
  set relisted_from  = p.previous_id,
      relisted_since = p.since,
      relisted_price = p.price
  from pairs p
  where l.id = p.id;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- As in 20261027090000_faster_scoring.sql, plus `photos_reused` (10): the
-- listing's photos were in an earlier ad of another model, or a private seller's
-- were in a dealer's earlier ad. Passed in p_text_signals by the view below.
create or replace function public.risk_from_signals(
  p_price          numeric,
  p_market_price   numeric,
  p_year           integer,
  p_mileage        integer,
  p_description    text,
  p_location       text,
  p_details_known  boolean,
  p_private_seller boolean,
  p_registrations  integer,
  p_service_book   boolean,
  p_origin         text,
  p_warranty_until date,
  p_relists        integer,
  p_on_sale_since  timestamptz,
  p_text_signals   text[]
)
returns table (risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (p_market_price - p_price) / p_market_price * 100
    end as below
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
    select 'imported', 10 where p_origin is not null and p_origin <> 'national'
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

-- As in 20261027090000_faster_scoring.sql, with photos_reused: the
-- listing's photos were in an earlier ad of another model, or, for a
-- private seller, in an earlier dealer's ad (copied photos, or a bike that
-- is not the seller's). The earlier ad is not flagged: it had them first.
-- Dealers' photos in other dealers' ads are left alone: the same stand
-- goes by different names on each site.
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
) r
where l.status in ('active', 'price_changed');
