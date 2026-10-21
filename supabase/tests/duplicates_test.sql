-- The same bike on both sites is one listing: the copy points to the
-- other and drops out of the market prices; a different bike stays.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type, first_seen_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2022, v.km, v.price, v.place, v.descr, 'private', v.seen
from public.motorcycles m,
     (values
       ('olx', 'd1', 12400, 6500, 'Porto', 'MT-07 de 2022, sempre na garagem, revisões na marca, pneus novos.', now() - interval '3 days'),
       ('standvirtual', 'd2', 12400, 6500, 'Porto', 'MT-07 de 2022, sempre na garagem, revisões na marca, pneus novos.', now()),
       ('olx', 'd3', 31000, 5200, 'Faro', 'Vendo mota com alguns riscos, muito estimada.', now())
     ) v(source, sid, km, price, place, descr, seen)
where m.slug = 'yamaha-mt-07';

do $$
declare
  marked int;
begin
  perform public.mark_duplicates();
  select count(*) into marked from public.listings where duplicate_of is not null;
  assert marked = 1, format('one duplicate, got %s', marked);
  assert exists (
    select from public.listings c join public.listings o on o.id = c.duplicate_of
    where c.source_listing_id in ('d1', 'd2') and o.source_listing_id in ('d1', 'd2')
  ), 'the copy points to the other site''s listing';
  assert (select duplicate_of from public.listings where source_listing_id = 'd3') is null,
    'a different bike is not a duplicate';
  assert (select priced_live_count from public.model_price_summary s
          join public.motorcycles m on m.id = s.motorcycle_id where m.slug = 'yamaha-mt-07') = 2,
    'the copy is left out of the market prices';
end $$;
