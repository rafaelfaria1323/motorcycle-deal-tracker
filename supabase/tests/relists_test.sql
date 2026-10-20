-- A live listing that matches a gone ad of the same model and year, gone up
-- to 90 days before it appeared, is a relist: it points to the old ad, keeps
-- the date the bike first went on sale and the old price. A dealer's new
-- bikes and ads gone long before are not relists.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type,
                             status, first_seen_at, last_seen_at, published_at, relisted_since)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, 6000, 'Porto', v.descr, 'private',
       v.status::public.listing_status, v.first_seen, v.last_seen, v.published, v.since
from public.motorcycles m,
     (values
       -- gone 10 days ago, itself a relist since 200 days ago
       ('olx', 'g1', 2021, 12400, 'MT-07 de 2021, sempre na garagem, revisões na marca, pneus novos.',
        'removed', now() - interval '40 days', now() - interval '10 days', now() - interval '50 days', now() - interval '200 days'),
       ('standvirtual', 'b1', 2021, 12400, 'MT-07 de 2021, sempre na garagem, revisões na marca, pneus novos.',
        'active', now(), now(), null, null),
       -- gone 100 days ago: too long before
       ('olx', 'g2', 2019, 30000, 'Mota de 2019 com muitos extras, escape e malas laterais incluídos.',
        'removed', now() - interval '150 days', now() - interval '100 days', null, null),
       ('olx', 'b2', 2019, 30000, 'Mota de 2019 com muitos extras, escape e malas laterais incluídos.',
        'active', now(), now(), null, null),
       -- a dealer's identical new bikes
       ('standvirtual', 'g3', 2024, 10, 'Nova, pronta a entregar, garantia de fábrica e financiamento.',
        'sold', now() - interval '20 days', now() - interval '5 days', now() - interval '25 days', null),
       ('standvirtual', 'b3', 2024, 0, 'Nova, pronta a entregar, garantia de fábrica e financiamento.',
        'active', now(), now(), null, null)
     ) v(source, sid, year, km, descr, status, first_seen, last_seen, published, since)
where m.slug = 'yamaha-mt-07';

do $$
declare
  marked int;
  b1 public.listings;
begin
  marked := public.mark_relists();
  assert marked = 1, format('one relist, got %s', marked);

  select * into b1 from public.listings where source_listing_id = 'b1';
  assert b1.relisted_from = (select id from public.listings where source_listing_id = 'g1'),
    'b1 points to the gone ad';
  assert b1.relisted_since = now() - interval '200 days',
    'on sale since the first listing of the chain';
  assert b1.relisted_price = 6000, 'the old price is kept';

  assert (select relisted_from from public.listings where source_listing_id = 'b2') is null,
    'an ad gone more than 90 days before is not a relist';
  assert (select relisted_from from public.listings where source_listing_id = 'b3') is null,
    'a dealer''s identical new bikes are separate stock';

  -- The relist is a risk reason: on sale for 200 days counting the old ad.
  assert (select reasons from public.listing_risk_scores rs
          join public.listings l on l.id = rs.listing_id
          where l.source_listing_id = 'b1') @> array['relisted_often'],
    'a relist on sale for over 90 days is relisted_often';
  assert not (select reasons && array['relisted', 'relisted_often']
              from public.listing_risk_scores rs
              join public.listings l on l.id = rs.listing_id
              where l.source_listing_id = 'b2'),
    'not a relist, no relist reason';

  update public.listings set relisted_since = null where source_listing_id = 'g1';
  marked := public.mark_relists();
  assert marked = 1, format('recomputed from scratch, got %s', marked);
  assert (select relisted_since from public.listings where source_listing_id = 'b1')
         = now() - interval '50 days',
    'without a chain, the earlier of publication and first sighting';
  assert (select reasons from public.listing_risk_scores rs
          join public.listings l on l.id = rs.listing_id
          where l.source_listing_id = 'b1') @> array['relisted'],
    'relisted once, on sale for 50 days';
end $$;
