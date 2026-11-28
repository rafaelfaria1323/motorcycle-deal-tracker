-- The spelling check (N.137): the ads it reads and what the rules read in
-- a stretch of text.

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             variant, description, year, mileage, price, location, status,
                             last_checked_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       'CB650R ' || v.sid, 'Vendo com e cluch e escape akrapovic', 2024, 3000, 8000,
       'Porto', 'active', v.seen
from public.motorcycles m,
     (values ('recent', now() - interval '2 days'),
             ('old', now() - interval '40 days')) v(sid, seen)
where m.slug = 'honda-cb650r';

-- An unmatched ad is never read.
insert into public.listings (source, source_listing_id, url, brand, model, variant,
                             description, price, status, last_checked_at)
values ('olx', 'unmatched', 'https://x/unmatched', 'Honda', 'NC750X', 'NC750X',
        'Vendo', 5000, 'active', now());

do $$
declare
  rows integer;
  first_id uuid;
  codes text[];
begin
  select count(*) into rows from public.spelling_check_texts(30);
  assert rows = 1, format('only the matched ad seen in 30 days, got %s', rows);
  assert (select variant from public.spelling_check_texts(30)) = 'CB650R recent',
    'the recent ad';
  assert (select count(*) from public.spelling_check_texts(60)) = 2, 'both in 60 days';

  -- Keyset pages: the second page starts after the first one's id.
  select id into first_id from public.spelling_check_texts(60, null, 1);
  assert (select count(*) from public.spelling_check_texts(60, first_id, 10)) = 1,
    'the page after the first';
  assert (select id from public.spelling_check_texts(60, first_id, 10)) > first_id,
    'in id order';

  -- The rules on a stretch of text, misspelt and corrected.
  select r.codes into codes from public.text_rule_codes(array['com e clotch novo']) r;
  assert codes = '{}', format('misspelt, got %s', codes);
  select r.codes into codes from public.text_rule_codes(array['com e clutch novo']) r;
  assert codes = '{e_clutch}', format('corrected, got %s', codes);

  -- Signals, extras and a mileage, in the texts' order.
  assert (select array_agg(r.i order by r.i)
          from public.text_rule_codes(array['teve um acidente', 'com quickshifter',
                                            'com 12.000 km', 'nada']) r) = '{1,2,3,4}',
    'one row per text';
  assert (select r.codes from public.text_rule_codes(array['teve um acidente', 'x']) r
          where r.i = 1) = '{possible_accident}', 'a signal';
  assert (select r.codes from public.text_rule_codes(array['x', 'com quickshifter']) r
          where r.i = 2) = '{quickshifter}', 'an extra';
  assert (select r.codes from public.text_rule_codes(array['com 12.000 km']) r)
         = '{mileage_in_text}', 'a mileage';
  assert (select count(*) from public.text_rule_codes('{}')) = 0, 'no texts';
end $$;
