-- A listing page's photos (20261024190000_listing_page_photos.sql): stored
-- over the search's one thumbnail, kept when the page has none; a listing
-- read before the photos were kept is read again, and marked when that fails.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, images, details_checked_at)
select 'standvirtual', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000,
       array['https://img/thumb.jpg'], v.checked
from public.motorcycles m,
     (values ('new', null::timestamptz), ('bare', null), ('old', now() - interval '5 days'))
       v(sid, checked)
where m.slug = 'yamaha-mt-07';

do $$
declare
  n int;
begin
  n := public.apply_listing_details('standvirtual', '[
    {"source_listing_id": "new", "images": ["https://img/1.jpg", "https://img/2.jpg"]},
    {"source_listing_id": "bare", "images": []}]');
  assert n = 2, format('two pages read, got %s', n);
  assert (select images from public.listings where source_listing_id = 'new')
       = array['https://img/1.jpg', 'https://img/2.jpg'], 'the page''s photos replace the thumbnail';
  assert (select images from public.listings where source_listing_id = 'bare')
       = array['https://img/thumb.jpg'], 'a page without photos keeps the thumbnail';
  assert (select photos_read_at = now() and details_checked_at = now()
          from public.listings where source_listing_id = 'new'), 'photos read now';

  perform public.mark_details_failed('standvirtual', array['new', 'old']);
  assert (select details_failed_at is null from public.listings where source_listing_id = 'new'),
    'a listing whose photos were read is not marked';
  assert (select details_failed_at = now() from public.listings where source_listing_id = 'old'),
    'one read before the photos were kept is marked when its page fails';
end $$;
