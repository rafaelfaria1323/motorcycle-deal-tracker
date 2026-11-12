-- olx_copies_to_skip: an OLX copy is skipped only when its Standvirtual
-- original is stored and the copy itself isn't (N.70).
insert into public.listings (source, source_listing_id, url, brand, model, price, seller_type)
values
  ('standvirtual', 'standvirtual.com/1', 'https://www.standvirtual.com/motos/anuncio/honda-cbr650r-ID8Q0aaa.html',
   'Honda', 'CBR650R', 8000, 'dealer'),
  ('olx', 'olx.pt/30', 'https://www.olx.pt/d/anuncio/honda-cbr-IDolx30.html',
   'Honda', 'CBR650R', 8500, 'dealer');

do $$
declare
  skipped text[];
begin
  select array_agg(s.id order by s.id) into skipped
  from public.olx_copies_to_skip(jsonb_build_object(
    'olx.pt/10', 'ID8Q0aaa',  -- original stored: skip
    'olx.pt/20', 'ID8Q1m16',  -- original never found: keep
    'olx.pt/30', 'ID8Q0aaa'   -- copy already stored as an OLX ad: keep
  )) as s(id);
  assert skipped = array['olx.pt/10'], format('skipped %s', skipped);

  assert not exists (select from public.olx_copies_to_skip(null)),
    'no copies, nothing to skip';
  assert not exists (select from public.olx_copies_to_skip('{}'::jsonb)),
    'empty, nothing to skip';
end;
$$;
