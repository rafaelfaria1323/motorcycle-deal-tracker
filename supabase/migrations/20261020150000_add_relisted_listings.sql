-- Relisted ads: a bike taken down and listed again as a new ad. The new
-- listing points at the previous ad and keeps when the bike first went on
-- sale and the previous ad's last price, so the app can show how long the
-- bike has really been for sale. Information only: it changes no score.

alter table public.listings
  add column relisted_from  uuid references public.listings (id) on delete set null,
  add column relisted_since timestamptz,
  add column relisted_price numeric(10, 2),
  add constraint listings_relisted_not_self
    check (relisted_from is null or relisted_from <> id);

-- Links each live listing to the most recent gone ad (removed or sold) of
-- the same bike (same model and year, duplicate_similarity >= threshold,
-- same rule as mark_duplicates) that disappeared before it was first seen,
-- at most p_max_gap_days earlier. Gone ads keep their own link, so a bike
-- relisted twice goes back to its first ad. Returns how many are linked.
create function public.mark_relists(
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
      and public.duplicate_similarity(
            a.mileage, b.mileage, a.price, b.price, a.location, b.location,
            a.description, b.description, a.seller_name, b.seller_name
          ) >= p_threshold
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

revoke all on function public.mark_relists(integer, integer)
  from public, anon, authenticated;

-- Every caller of mark_duplicates (refresh, enrich) also marks relists.
-- Recomputes duplicate flags from scratch for the live listings.
-- The newer listing points at the oldest one it matches. Returns how many
-- listings were flagged. Nothing is deleted.
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
  where duplicate_of is not null or duplicate_score is not null;

  with live as (
    select * from public.listings
    where status in ('active', 'price_changed')
  ),
  pairs as (
    select
      b.id as dup_id,
      a.id as original_id,
      a.first_seen_at as original_seen,
      public.duplicate_similarity(
        a.mileage, b.mileage, a.price, b.price, a.location, b.location,
        a.description, b.description, a.seller_name, b.seller_name
      ) as score
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

select public.mark_duplicates();
