-- Duplicate and relist marks: write only the rows whose marks change.
--
-- mark_duplicates and mark_relists cleared every live listing's marks and
-- wrote them all back on every run (every 2 hours), so each run rewrote
-- the same rows (dead row versions, WAL) although almost nothing changed.
-- Both now work out each live listing's marks first and update only the
-- rows where they differ. The rules are the same: the same pairs, the
-- same earliest original, chains collapsed to the first listing (now in
-- one step, whatever their length), a gone listing keeps its marks, and
-- the same counts are returned.

create or replace function public.mark_duplicates(p_threshold integer default 70)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with recursive live as (
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
  ),
  -- Chains: if C duplicates B and B duplicates A, C points at A. An
  -- original is always seen before its copy, so a chain never loops.
  chain (dup_id, root_id, score, depth) as (
    select dup_id, original_id, score, 0 from best
    union all
    select c.dup_id, b.original_id, c.score, c.depth + 1
    from chain c
    join best b on b.dup_id = c.root_id
  ),
  resolved as (
    select distinct on (dup_id) dup_id, root_id, score
    from chain
    order by dup_id, depth desc
  ),
  wanted as (
    select l.id, r.root_id, r.score
    from live l
    left join resolved r on r.dup_id = l.id
  ),
  changed as (
    update public.listings l
    set duplicate_of = w.root_id,
        duplicate_score = w.score
    from wanted w
    where l.id = w.id
      and (l.duplicate_of, l.duplicate_score)
          is distinct from (w.root_id, w.score)
    returning 1
  )
  select count(*) into n from best;

  -- A gone listing keeps its mark; one that points at a listing that is
  -- now itself a copy follows it to the first.
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

revoke all on function public.mark_duplicates(integer)
  from public, anon, authenticated;
grant execute on function public.mark_duplicates(integer) to service_role;

create or replace function public.mark_relists(
  p_threshold integer default 70,
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
  ),
  wanted as (
    select b.id, p.previous_id, p.since, p.price
    from public.listings b
    left join pairs p on p.id = b.id
    where b.status in ('active', 'price_changed')
  ),
  changed as (
    update public.listings l
    set relisted_from  = w.previous_id,
        relisted_since = w.since,
        relisted_price = w.price
    from wanted w
    where l.id = w.id
      and (l.relisted_from, l.relisted_since, l.relisted_price)
          is distinct from (w.previous_id, w.since, w.price)
    returning 1
  )
  select count(*) into n from pairs;

  return n;
end;
$$;

revoke all on function public.mark_relists(integer, integer)
  from public, anon, authenticated;
grant execute on function public.mark_relists(integer, integer) to service_role;
