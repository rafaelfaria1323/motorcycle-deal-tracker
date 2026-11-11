-- N.55: the weekly description check. The collector (bin/text_audit.dart)
-- sends a sample of the week's ads to a free LLM and compares what it reads
-- with what the rules read; the disagreements are a report for fixing the
-- rules (with tests). Nothing here changes a score or a listing.

-- Up to p_limit matched, non-duplicate ads first seen since p_since with a
-- description worth reading, spread over the week (ordered by a hash of
-- the id, so the same week gives the same sample), with what the rules
-- read from their text: description_signals, listing_extras and
-- mileage_in_text. The description is cut to 2000 characters.
create function public.text_audit_sample(p_since timestamptz, p_limit integer)
returns table (
  id uuid,
  url text,
  variant text,
  description text,
  signals text[],
  extras text[],
  mileage_in_text integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.url, l.variant, left(l.description, 2000),
         coalesce(l.text_signals, public.description_signals(l.variant, l.description)),
         coalesce(l.text_extras, public.listing_extras(l.variant, l.description)),
         public.mileage_in_text(l.description)
  from public.listings l
  where l.motorcycle_id is not null
    and l.duplicate_of is null
    and l.first_seen_at >= p_since
    and length(l.description) >= 80
  order by md5(l.id::text)
  limit greatest(p_limit, 0)
$$;

revoke all on function public.text_audit_sample(timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.text_audit_sample(timestamptz, integer)
  to service_role;

-- Up to p_limit ads first seen since p_since that match no model, one per
-- brand, model and title (sellers repeat them): the titles the rules
-- couldn't place, for the check to say whether one is a followed model.
create function public.unmatched_title_sample(p_since timestamptz, p_limit integer)
returns table (
  id uuid,
  url text,
  brand text,
  model text,
  variant text
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.url, s.brand, s.model, s.variant
  from (
    select distinct on (lower(l.brand), lower(l.model), lower(coalesce(l.variant, '')))
           l.id, l.url, l.brand, l.model, l.variant
    from public.listings l
    where l.motorcycle_id is null
      and l.first_seen_at >= p_since
    order by lower(l.brand), lower(l.model), lower(coalesce(l.variant, '')), l.id
  ) s
  order by md5(s.id::text)
  limit greatest(p_limit, 0)
$$;

revoke all on function public.unmatched_title_sample(timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.unmatched_title_sample(timestamptz, integer)
  to service_role;
