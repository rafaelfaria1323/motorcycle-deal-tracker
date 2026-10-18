create extension if not exists pg_trgm with schema extensions;

alter table public.listings
  add column duplicate_of    uuid references public.listings (id) on delete set null,
  add column duplicate_score smallint,
  add constraint listings_duplicate_not_self
    check (duplicate_of is null or duplicate_of <> id);

create index listings_duplicate_of_idx
  on public.listings (duplicate_of) where duplicate_of is not null;

-- How likely two listings are the same bike (0-120). 70+ = likely duplicate.
create function public.duplicate_similarity(
  p_mileage_a     integer, p_mileage_b     integer,
  p_price_a       numeric, p_price_b       numeric,
  p_location_a    text,    p_location_b    text,
  p_description_a text,    p_description_b text,
  p_seller_a      text,    p_seller_b      text
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select
    -- mileage
    case
      when p_mileage_a is null or p_mileage_b is null then 0
      when p_mileage_a = p_mileage_b
        then case when p_mileage_a >= 500 then 40 else 10 end
      when abs(p_mileage_a - p_mileage_b) <= 100
           and greatest(p_mileage_a, p_mileage_b) >= 500 then 20
      else 0
    end
    -- price
    + case
      when p_price_a is null or p_price_b is null
           or greatest(p_price_a, p_price_b) <= 0 then 0
      when abs(p_price_a - p_price_b) / greatest(p_price_a, p_price_b) <= 0.03 then 20
      when abs(p_price_a - p_price_b) / greatest(p_price_a, p_price_b) <= 0.10 then 10
      else 0
    end
    -- location
    + case
      when nullif(btrim(p_location_a), '') is not null
           and lower(btrim(p_location_a)) = lower(btrim(p_location_b)) then 20
      else 0
    end
    -- description text, only when both are long enough to compare
    + case
      when char_length(coalesce(p_description_a, '')) < 40
           or char_length(coalesce(p_description_b, '')) < 40 then 0
      when extensions.similarity(lower(p_description_a), lower(p_description_b)) >= 0.8 then 30
      when extensions.similarity(lower(p_description_a), lower(p_description_b)) >= 0.6 then 15
      else 0
    end
    -- dealer name
    + case
      when nullif(btrim(p_seller_a), '') is not null
           and lower(btrim(p_seller_a)) = lower(btrim(p_seller_b)) then 10
      else 0
    end
$$;

-- Recomputes duplicate flags from scratch for the live listings.
-- The newer listing points at the oldest one it matches. Returns how many
-- listings were flagged. Nothing is deleted.
create function public.mark_duplicates(p_threshold integer default 70)
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

  return n;
end;
$$;

revoke all on function public.mark_duplicates(integer)
  from public, anon, authenticated;