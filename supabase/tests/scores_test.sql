-- Scoring: the equipment slice and the extras it reads, and the Deal
-- Score ranking a cheaper bike above a dearer one of the same year and km.
do $$
begin
  assert public.equipment_score(array['quickshifter']) = 70, 'one extra: 70';
  assert public.equipment_score(array['quickshifter', 'exhaust']) = 80, '+10 for each more';
  assert public.equipment_score(array['a', 'b', 'c', 'd', 'e', 'f']) = 100, 'at most 100';
  assert public.equipment_score(array[]::text[]) is null, 'none: the slice is skipped';
  assert public.listing_extras('Akrapovic', 'Tem quickshifter, sem punhos aquecidos')
           = array['exhaust', 'quickshifter'], '"sem ..." is not an extra';
end $$;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, seller_type)
select 'olx', 's' || i, 'https://x/s' || i, m.id, m.brand, m.model, 2022, 12000,
       6000 + i * 250, 'Lisboa', 'Mota estimada número ' || i || ', revisões feitas.', 'dealer'
from public.motorcycles m, generate_series(0, 8) i
where m.slug = 'honda-cb650r';

do $$
declare
  cheapest smallint;
  dearest smallint;
begin
  perform public.recalculate_deal_scores();
  select deal_score into cheapest from public.listings where source_listing_id = 's0';
  select deal_score into dearest from public.listings where source_listing_id = 's8';
  assert cheapest is not null and dearest is not null, 'both scored';
  assert cheapest > dearest, format('cheapest %s should beat dearest %s', cheapest, dearest);
  assert (select score_breakdown is not null from public.listings where source_listing_id = 's0'),
    'the explanation is stored';
end $$;
