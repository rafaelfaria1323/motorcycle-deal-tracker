-- N.135: Honda's E-Clutch read from the ad, worth a point like the
-- quickshifter, and matched by a saved search's equipment.
do $$
declare
  cases text[][] := array[
    ['Honda CB650R E-Clutch', 'e_clutch'],
    ['CBR650R eclutch 2024', 'e_clutch'],
    ['versão E Clutch, quickshifter', 'e_clutch,quickshifter'],
    ['Com embraiagem eletrónica Honda', 'e_clutch'],
    ['embraiagem automática electrónica', 'e_clutch'],
    ['Cb 650r e cluch', 'e_clutch'],
    ['Honda CB 650R E-cluch 2025', 'e_clutch'],
    ['E-Cluth de origem', 'e_clutch'],
    ['versão e-clucth', 'e_clutch'],
    ['sem e-cluch', ''],
    ['versão sem e-clutch', ''],
    ['sem eclutch', ''],
    ['kit de embraiagem novo', ''],
    ['embraiagem deslizante', ''],
    ['clutch cable changed', ''],
    ['the clutch is new', '']
  ];
  i int;
  got text;
begin
  for i in 1 .. array_length(cases, 1) loop
    got := array_to_string(public.listing_extras(null, cases[i][1]), ',');
    assert got = cases[i][2], format('%s: expected "%s", got "%s"', cases[i][1], cases[i][2], got);
  end loop;
  -- Standvirtual's version alone names it.
  assert public.listing_extras('CB650R E-Clutch', null) = array['e_clutch'], 'the version';
  assert public.valued_extras(array['e_clutch', 'mirrors']) = array['e_clutch'], 'worth a point';
end $$;

-- A stored ad keeps it (the trigger), and the scores carry it.
do $$
declare
  l uuid;
begin
  insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                               year, mileage, price, variant)
  select 'standvirtual', 'ec-1', 'https://x/ec-1', m.id, m.brand, m.model,
         2024, 3000, 7900, 'CB650R E-Clutch'
  from public.motorcycles m
  where m.brand = 'Honda' and m.model = 'CB650R'
  returning id into l;
  assert (select text_extras from public.listings where id = l) = array['e_clutch'],
    'the trigger stores it';
  perform public.recalculate_deal_scores();
  assert (select score_breakdown -> 'extras' from public.listings where id = l)
           = '["e_clutch"]'::jsonb, 'the breakdown the card reads';
end $$;
