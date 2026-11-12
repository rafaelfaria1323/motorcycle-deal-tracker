-- N.62 (20261112120000_fact_edits.sql): seller edits in their own favour
-- (fewer km, a newer year) become risk reasons.

do $$
begin
  assert public.fact_edit_signals(13000, false, 31000, 2020, 2020) = array['mileage_lowered'],
    'km lowered';
  assert public.fact_edit_signals(30500, false, 31000, 2020, 2020) = '{}'::text[],
    'under 1 000 km is a small correction';
  assert public.fact_edit_signals(13000, true, 31000, 2020, 2020) = '{}'::text[],
    'km read from the text';
  assert public.fact_edit_signals(13000, false, null, 2021, 2020) = array['year_raised'],
    'newer year';
  assert public.fact_edit_signals(13000, false, 13000, 2019, 2020) = '{}'::text[],
    'an older year is against the seller';
  assert public.fact_edit_signals(null, false, null, null, null) = '{}'::text[], 'nothing known';
end $$;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price)
select 'olx', 'fe-1', 'https://x/fe-1', m.id, m.brand, m.model, 2020, 31000, 6000
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  l public.listings;
begin
  select * into l from public.listings where source_listing_id = 'fe-1';
  assert l.mileage_max_seen = 31000 and l.year_first_seen = 2020, format('first seen: %s', l);

  -- The seller edits the ad, as apply_listing_facts would.
  perform public.apply_listing_facts('olx',
    '[{"source_listing_id": "fe-1", "mileage": 13000, "year": 2021}]'::jsonb);
  select * into l from public.listings where source_listing_id = 'fe-1';
  assert l.mileage = 13000 and l.mileage_max_seen = 31000 and l.year_first_seen = 2020,
    format('kept: %s', l);
  assert (select reasons @> array['mileage_lowered', 'year_raised']
          from public.listing_risk_scores where listing_id = l.id),
    'both edits are risk reasons';

  -- Back up: still the highest seen; no reason any more.
  perform public.apply_listing_facts('olx',
    '[{"source_listing_id": "fe-1", "mileage": 31000, "year": 2020}]'::jsonb);
  assert not (select reasons && array['mileage_lowered', 'year_raised']
              from public.listing_risk_scores where listing_id = l.id),
    'undone by the seller';
end $$;

-- A km read from the description first, then the field: no edit.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, description, price)
select 'olx', 'fe-2', 'https://x/fe-2', m.id, m.brand, m.model, 2020,
       'Mota com 31.000 km, revisões feitas.', 6000
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  l public.listings;
begin
  select * into l from public.listings where source_listing_id = 'fe-2';
  assert l.mileage_from_text and l.mileage_max_seen is null, format('from text: %s', l);
  perform public.apply_listing_facts('olx',
    '[{"source_listing_id": "fe-2", "mileage": 13000}]'::jsonb);
  select * into l from public.listings where source_listing_id = 'fe-2';
  assert l.mileage = 13000 and l.mileage_max_seen = 13000, format('the field: %s', l);
  assert not (select reasons @> array['mileage_lowered']
              from public.listing_risk_scores where listing_id = l.id),
    'the field replacing the text is no edit';
end $$;
