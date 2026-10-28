-- The photo CDN's robots.txt refused every photo in the first runs (our
-- parser ignored its Allow lines), and the photo step still marked those
-- listings as checked, with no photos. Unmark every listing checked
-- without a single fingerprint, so the next runs read its photos. A
-- listing whose photos are really gone is read once more, which is cheap.
update public.listings l
set photos_hashed_at = null,
    photos_examined_at = null,
    photo_hints = '[]'
where l.photos_hashed_at is not null
  and not exists (
    select 1 from public.listing_photo_hashes h where h.listing_id = l.id
  );
