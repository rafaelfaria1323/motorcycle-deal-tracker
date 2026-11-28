-- The weekly spelling check (N.137): words in real ads one or two letters
-- off a word the description rules depend on ("e cluch" for "e clutch"),
-- found before someone notices a missed bike. The collector
-- (bin/spelling_check.dart) reads the recent ads' text, finds the near
-- words, and asks these rules what a short stretch of text reads as with
-- the word as written and as corrected. A report only: nothing is written.

-- The matched, non-duplicate ads seen in the last p_days days: title (or
-- version) and description, p_limit at a time after p_after (keyset, by id).
create function public.spelling_check_texts(
  p_days integer,
  p_after uuid default null,
  p_limit integer default 500
) returns table (id uuid, url text, variant text, description text)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.url, l.variant, left(l.description, 4000)
  from public.listings l
  where l.motorcycle_id is not null
    and l.duplicate_of is null
    and l.last_checked_at >= now() - make_interval(days => greatest(p_days, 1))
    and (p_after is null or l.id > p_after)
  order by l.id
  limit least(greatest(p_limit, 0), 1000)
$$;

revoke all on function public.spelling_check_texts(integer, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.spelling_check_texts(integer, uuid, integer)
  to service_role;

-- What the description rules read in each of p_texts (at most 1000): the
-- signals (description_signals), the extras (listing_extras) and, as
-- 'mileage_in_text', whether a mileage is read from it. i is the text's
-- position in p_texts, from 1.
create function public.text_rule_codes(p_texts text[])
returns table (i integer, codes text[])
language sql
stable
security definer
set search_path = ''
as $$
  select t.i::integer,
         array(
           select distinct c
           from unnest(
             public.description_signals(null, t.text)
             || public.listing_extras(null, t.text)
             || case when public.mileage_in_text(t.text) is not null
                  then array['mileage_in_text'] else '{}'::text[] end
           ) c
           order by c
         )
  from unnest(p_texts[1:1000]) with ordinality t(text, i)
  order by t.i
$$;

revoke all on function public.text_rule_codes(text[])
  from public, anon, authenticated;
grant execute on function public.text_rule_codes(text[]) to service_role;
