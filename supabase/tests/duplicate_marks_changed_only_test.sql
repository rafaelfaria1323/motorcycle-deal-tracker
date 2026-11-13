-- mark_duplicates and mark_relists write only the rows whose marks
-- change: a second run rewrites nothing, chains still end at the first
-- listing, a gone listing keeps its mark and a listing no longer a copy
-- loses it.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type,
                             status, first_seen_at, last_seen_at)
select v.source, v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, v.price, v.place, v.descr, 'private',
       v.status::public.listing_status, v.seen, v.last_seen
from public.motorcycles m,
     (values
       -- a chain by photos only: c2 shares photos with b2, b2 with a2
       ('olx', 'a2', 2022, 9000, 6500, 'Porto', 'Primeira descrição, sem nada em comum.',
        'active', now() - interval '5 days', now()),
       ('standvirtual', 'b2', 2022, 9200, 6400, 'Braga', 'Outro texto completamente diferente aqui.',
        'active', now() - interval '4 days', now()),
       ('olx', 'c2', 2022, 9900, 6300, 'Faro', 'Terceira forma de escrever o anúncio.',
        'active', now() - interval '3 days', now()),
       -- the same bike on both sites, by text
       ('olx', 'd2', 2021, 12400, 6000, 'Lisboa', 'MT-07 de 2021, sempre na garagem, revisões na marca, pneus novos.',
        'active', now() - interval '2 days', now()),
       ('standvirtual', 'e2', 2021, 12400, 6000, 'Lisboa', 'MT-07 de 2021, sempre na garagem, revisões na marca, pneus novos.',
        'active', now() - interval '1 day', now()),
       -- gone, then back under a new ad: a relist
       ('olx', 'g2', 2019, 30000, 5000, 'Coimbra', 'Mota de 2019 com muitos extras, escape e malas laterais incluídos.',
        'removed', now() - interval '40 days', now() - interval '10 days'),
       ('olx', 'h2', 2019, 30000, 4800, 'Coimbra', 'Mota de 2019 com muitos extras, escape e malas laterais incluídos.',
        'active', now() - interval '2 days', now())
     ) v(source, sid, year, km, price, place, descr, status, seen, last_seen)
where m.slug = 'yamaha-mt-07';

insert into public.listing_photo_matches (listing_id, other_id, shared)
select x.id, y.id, 2
from public.listings x, public.listings y
where (x.source_listing_id, y.source_listing_id)
      in (('a2', 'b2'), ('b2', 'a2'), ('b2', 'c2'), ('c2', 'b2'));

create temporary table listing_versions as
select id, ctid::text as version from public.listings where false;

do $$
declare
  marked int;
  rewritten int;
  a2 uuid := (select id from public.listings where source_listing_id = 'a2');
  d2 uuid := (select id from public.listings where source_listing_id = 'd2');
begin
  marked := public.mark_duplicates();
  assert marked = 3, format('b2, c2 and e2 are copies, got %s', marked);
  assert (select duplicate_of from public.listings where source_listing_id = 'b2') = a2,
    'b2 points at a2';
  assert (select duplicate_of from public.listings where source_listing_id = 'c2') = a2,
    'the chain c2 -> b2 -> a2 ends at the first listing';
  assert (select duplicate_score from public.listings where source_listing_id = 'c2') = 100,
    'the score is the one with its own original (shared photos)';
  assert (select duplicate_of from public.listings where source_listing_id = 'e2') = d2,
    'the copy by text points at the first one';
  assert (select relisted_from from public.listings where source_listing_id = 'h2')
         = (select id from public.listings where source_listing_id = 'g2'),
    'h2 is a relist of g2';

  -- A second run with nothing new rewrites no row.
  insert into listing_versions select id, ctid::text from public.listings;
  marked := public.mark_duplicates();
  assert marked = 3, format('the same three copies, got %s', marked);
  select count(*) into rewritten
  from public.listings l join listing_versions v on v.id = l.id
  where l.ctid::text <> v.version;
  assert rewritten = 0, format('nothing changed, %s row(s) rewritten', rewritten);

  -- c2 is gone: it keeps its mark. e2 changes its text: no longer a copy,
  -- and only e2 is written.
  update public.listings set status = 'removed' where source_listing_id = 'c2';
  update public.listings
  set description = 'Agora um texto que não se parece com nenhum outro.',
      location = 'Évora', price = 7000, mileage = 20000
  where source_listing_id = 'e2';
  truncate listing_versions;
  insert into listing_versions select id, ctid::text from public.listings;
  marked := public.mark_duplicates();
  assert marked = 1, format('only b2 is still a live copy, got %s', marked);
  assert (select duplicate_of from public.listings where source_listing_id = 'c2') = a2,
    'a gone listing keeps its mark';
  assert (select duplicate_of is null and duplicate_score is null
          from public.listings where source_listing_id = 'e2'),
    'a listing no longer a copy loses its mark';
  select count(*) into rewritten
  from public.listings l join listing_versions v on v.id = l.id
  where l.ctid::text <> v.version;
  assert rewritten = 1, format('only e2 rewritten, got %s', rewritten);

  -- b2 goes too and a2 is now a copy of an older listing: the gone
  -- listings that pointed at a2 follow it to the first.
  update public.listings set status = 'removed' where source_listing_id = 'b2';
  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price, location, description, seller_type,
                               first_seen_at)
  select 'standvirtual', 'z2', 'https://x/z2', m.id, m.brand, m.model,
         2022, 8900, 6600, 'Aveiro', 'Ainda outro texto, nada a ver.', 'private',
         now() - interval '9 days'
  from public.motorcycles m where m.slug = 'yamaha-mt-07';
  insert into public.listing_photo_matches (listing_id, other_id, shared)
  select x.id, y.id, 2
  from public.listings x, public.listings y
  where (x.source_listing_id, y.source_listing_id) in (('z2', 'a2'), ('a2', 'z2'));
  perform public.mark_duplicates();
  assert (select duplicate_of from public.listings where source_listing_id = 'a2')
         = (select id from public.listings where source_listing_id = 'z2'),
    'a2 is a copy of the older z2';
  assert (select count(*) from public.listings
          where source_listing_id in ('b2', 'c2')
            and duplicate_of = (select id from public.listings where source_listing_id = 'z2')) = 2,
    'the gone copies follow a2 to z2';

  -- Relists: a second run rewrites nothing either.
  truncate listing_versions;
  insert into listing_versions select id, ctid::text from public.listings;
  marked := public.mark_relists();
  assert marked = 1, format('h2 is still the one relist, got %s', marked);
  select count(*) into rewritten
  from public.listings l join listing_versions v on v.id = l.id
  where l.ctid::text <> v.version;
  assert rewritten = 0, format('no relist rewritten, got %s', rewritten);

  -- h2 changes into another bike: its relist marks go.
  update public.listings set year = 2020 where source_listing_id = 'h2';
  marked := public.mark_relists();
  assert marked = 0, format('no relist left, got %s', marked);
  assert (select relisted_from is null and relisted_since is null and relisted_price is null
          from public.listings where source_listing_id = 'h2'),
    'a listing no longer a relist loses its marks';
end $$;
