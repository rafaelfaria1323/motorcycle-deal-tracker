-- A stored ad's photos follow the seller's edits (N.56). OLX's search
-- results hold every photo of an ad, but `save` only inserts, so photos
-- replaced later never arrived: the app kept addresses that may be gone,
-- and the fingerprints and damage hints stayed on the old photos.
-- `apply_listing_facts` now also takes `images` (sent by the collector
-- for OLX only: Standvirtual's search has one thumbnail, its listing
-- page the rest). When the first three change (the ones fingerprinted
-- and examined) the listing waits for the photo step again and the
-- admins' marks on them go; any change lets every photo be asked for
-- again. Facts without `images` (the collector on main) change nothing.
create or replace function public.apply_listing_facts(p_source text, p_facts jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  -- Marks belong to the photos they were made on.
  delete from public.photo_marks k
  using public.listings l, jsonb_to_recordset(p_facts) as f(
    source_listing_id text,
    images            text[]
  )
  where k.listing_id = l.id
    and l.source = p_source
    and l.source_listing_id = f.source_listing_id
    and cardinality(f.images) > 0
    and f.images[1:3] is distinct from l.images[1:3];

  update public.listings l
  set year        = coalesce(f.year, l.year),
      mileage     = coalesce(f.mileage, l.mileage),
      mileage_from_text = l.mileage_from_text and f.mileage is null,
      variant     = coalesce(f.variant, l.variant),
      description = coalesce(f.description, l.description),
      location    = coalesce(f.location, l.location),
      images      = case when f.new_photos then f.images else l.images end,
      photos_hashed_at = case
        when f.new_photos and f.images[1:3] is distinct from l.images[1:3]
        then null else l.photos_hashed_at end,
      photos_examined_at = case
        when f.new_photos and f.images[1:3] is distinct from l.images[1:3]
        then null else l.photos_examined_at end,
      photos_examined_all_at = case
        when f.new_photos then null else l.photos_examined_all_at end
  from (
    -- As the phone-number trigger stores them, so an unchanged text
    -- compares equal.
    select r.source_listing_id, r.year, r.mileage,
           public.without_phone_numbers(r.variant) as variant,
           public.without_phone_numbers(r.description) as description,
           r.location, r.images,
           coalesce(cardinality(r.images) > 0
                    and r.images is distinct from s.images, false) as new_photos
    from jsonb_to_recordset(p_facts) as r(
      source_listing_id text,
      year              smallint,
      mileage           integer,
      variant           text,
      description       text,
      location          text,
      images            text[]
    )
    left join public.listings s
      on s.source = p_source and s.source_listing_id = r.source_listing_id
  ) f
  where l.source = p_source
    and l.source_listing_id = f.source_listing_id
    and (   (f.year is not null and f.year is distinct from l.year)
         or (f.mileage is not null
             and (f.mileage is distinct from l.mileage or l.mileage_from_text))
         or (f.variant is not null and f.variant is distinct from l.variant)
         or (f.description is not null
             and f.description is distinct from l.description)
         or (f.location is not null and f.location is distinct from l.location)
         or f.new_photos);

  get diagnostics n = row_count;
  return n;
end;
$$;
