-- A saved search asking for equipment matches only listings whose ad
-- mentions all of it; unknown codes are refused.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000b1');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, score_breakdown)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000, v.breakdown::jsonb
from public.motorcycles m,
     (values ('both',  '{"extras": ["luggage", "quickshifter"]}'),
             ('qs',    '{"extras": ["quickshifter"]}'),
             ('none',  '{"extras": []}'),
             ('plain', null)) v(sid, breakdown)
where m.slug = 'yamaha-mt-07';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000b1';
insert into public.saved_searches (name, extras) values ('QS', '{quickshifter}'),
                                                        ('QS e malas', '{quickshifter,luggage}'),
                                                        ('Tudo', '{}');
do $$
declare
  refused boolean := false;
begin
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'QS') = array['both', 'qs'], 'quickshifter';
  assert (select array_agg(l.source_listing_id)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          join public.listings l on l.id = m.listing_id
          where s.name = 'QS e malas') = array['both'], 'all of them required';
  assert (select count(*)
          from public.saved_search_matches m
          join public.saved_searches s on s.id = m.saved_search_id
          where s.name = 'Tudo') = 4, 'no extras: everything';

  begin
    insert into public.saved_searches (name, extras) values ('x', '{turbo}');
  exception when check_violation then refused := true;
  end;
  assert refused, 'an unknown extra is refused';
end $$;
reset role;
