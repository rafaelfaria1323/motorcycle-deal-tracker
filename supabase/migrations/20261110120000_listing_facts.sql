-- Two faults Rafael found on 2026-11-10.
--
-- 1. A stored ad never took the seller's later edits: the collector inserts
--    a listing once and afterwards only follows its price, dates and model.
--    An MT-07 stored at 6 500 km stayed there after the ad said 8 500.
--    apply_listing_facts() brings what the site says now.
--
-- 2. OLX sellers file a Tracer 9 GT or an XSR 900 under the model "MT-09";
--    the collector read that field as part of the name. Its resolver now
--    rules out a brand's other lines (collector: relatedModelWords); every
--    import corrects the ads it reads (rematch_listings), and the update
--    below corrects the stored ones no import reads any more (gone ads
--    still feed the model's exit prices and time to sale).

-- What the site says now about listings already stored. A fact the site
-- doesn't give (null) never erases the stored one: Standvirtual's search
-- pages hold no description, and an empty mileage field keeps the value
-- read from the text. A mileage the site gives replaces one read from the
-- text. Returns how many listings changed.
create function public.apply_listing_facts(p_source text, p_facts jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set year        = coalesce(f.year, l.year),
      mileage     = coalesce(f.mileage, l.mileage),
      mileage_from_text = l.mileage_from_text and f.mileage is null,
      variant     = coalesce(f.variant, l.variant),
      description = coalesce(f.description, l.description),
      location    = coalesce(f.location, l.location)
  from (
    -- As the phone-number trigger stores them, so an unchanged text
    -- compares equal.
    select r.source_listing_id, r.year, r.mileage,
           public.without_phone_numbers(r.variant) as variant,
           public.without_phone_numbers(r.description) as description,
           r.location
    from jsonb_to_recordset(p_facts) as r(
      source_listing_id text,
      year              smallint,
      mileage           integer,
      variant           text,
      description       text,
      location          text
    )
  ) f
  where l.source = p_source
    and l.source_listing_id = f.source_listing_id
    and (   (f.year is not null and f.year is distinct from l.year)
         or (f.mileage is not null
             and (f.mileage is distinct from l.mileage or l.mileage_from_text))
         or (f.variant is not null and f.variant is distinct from l.variant)
         or (f.description is not null
             and f.description is distinct from l.description)
         or (f.location is not null and f.location is distinct from l.location));

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_listing_facts(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_listing_facts(text, jsonb) to service_role;

-- Stored OLX ads of another line filed under a model (the words are the
-- collector's relatedModelWords): unmatched, under their title, as the
-- collector stores an ad it can't match. A model that is itself of that
-- line (Tracer 7) keeps its ads.
update public.listings l
set motorcycle_id = null,
    model = coalesce(l.variant, l.model)
from public.motorcycles m,
     (values ('yamaha', 'tracer'), ('yamaha', 'trecer'), ('yamaha', 'xsr'),
             ('yamaha', 'niken'), ('yamaha', 'tenere'),
             ('honda', 'transalp'), ('honda', 'xadv')) w(brand, word)
where l.motorcycle_id = m.id
  and l.source = 'olx'
  and lower(m.brand) = w.brand
  and regexp_replace(lower(coalesce(l.variant, '')), '[^a-z0-9]', '', 'g')
      like '%' || w.word || '%'
  and not exists (
    select 1 from unnest(array[m.model] || m.aliases) name
    where regexp_replace(lower(name), '[^a-z0-9]', '', 'g')
          like '%' || w.word || '%');
