-- The A2 licence (N.63): each catalog model's power, listings ready for
-- A2 or restrictable to it, and saved searches filtering on them.
do $$
begin
  assert public.a2_fit(30.9, '{}') = 'ready', '35 kW or less';
  assert public.a2_fit(35, null) = 'ready';
  assert public.a2_fit(54, '{}') = 'restrictable', 'up to 70 kW a kit limits it';
  assert public.a2_fit(70, '{}') = 'restrictable';
  assert public.a2_fit(87.5, '{}') is null, 'over twice the limit';
  assert public.a2_fit(54, '{a2_limited}') = 'ready', 'the ad says it is limited';
  assert public.a2_fit(null, '{a2_limited}') = 'ready', 'also of a model of unknown power';
  assert public.a2_fit(54, '{a2_unlocked}') = 'restrictable', 'unlocked: can be limited again';
  assert public.a2_fit(null, '{}') is null, 'unknown power';

  assert not exists (
    select 1 from public.motorcycles
    where slug in ('yamaha-mt-07', 'yamaha-r7', 'yamaha-tracer-7', 'yamaha-r1',
                   'yamaha-r3', 'yamaha-r9', 'honda-cb125r', 'honda-cb300r',
                   'honda-cbr500r', 'honda-cb750-hornet', 'honda-cb650r',
                   'honda-cbr650r', 'honda-cbr600rr')
      and power_kw is null
  ), 'every catalog model has its power';
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a2');
insert into public.user_models (user_id, motorcycle_id, min_year)
select '00000000-0000-0000-0000-0000000000a2', m.id, m.min_year
from public.motorcycles m where m.is_active;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, variant, description)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 6000, v.variant, v.descr
from public.motorcycles m
join (values ('yamaha-mt-07', 'a2-1', 'MT-07', 'Versão A2, limitada a 35 kW.'),
             ('yamaha-mt-07', 'a2-2', 'MT-07', 'Full power.'),
             ('yamaha-r1', 'a2-3', 'R1', null),
             ('honda-cb650r', 'a2-4', 'CB650R', null)) v(slug, sid, variant, descr)
  on m.slug = v.slug;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a2';
set local test.jwt = '{"is_anonymous": false}';

insert into public.saved_searches (name, a2) values ('Pronta', 'ready'),
                                                    ('Limitável', 'restrictable'),
                                                    ('Qualquer', null);

do $$
declare
  refused boolean := false;
begin
  assert (select public.a2(l) from public.listings l where source_listing_id = 'a2-1') = 'ready';
  assert (select public.a2(l) from public.listings l where source_listing_id = 'a2-2') = 'restrictable';
  assert (select public.a2(l) from public.listings l where source_listing_id = 'a2-3') is null;

  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches sm
          join public.saved_searches s on s.id = sm.saved_search_id
          join public.listings l on l.id = sm.listing_id
          where s.name = 'Pronta' and l.source_listing_id like 'a2-%')
         = array['a2-1'], 'ready only';
  assert (select array_agg(l.source_listing_id order by l.source_listing_id)
          from public.saved_search_matches sm
          join public.saved_searches s on s.id = sm.saved_search_id
          join public.listings l on l.id = sm.listing_id
          where s.name = 'Limitável' and l.source_listing_id like 'a2-%')
         = array['a2-1', 'a2-2', 'a2-4'], 'ready or restrictable';
  assert (select count(*)
          from public.saved_search_matches sm
          join public.saved_searches s on s.id = sm.saved_search_id
          join public.listings l on l.id = sm.listing_id
          where s.name = 'Qualquer' and l.source_listing_id like 'a2-%') = 3,
    'any (the R1 is followed by nobody)';

  begin
    insert into public.saved_searches (name, a2) values ('Má', 'a1');
  exception when check_violation then refused := true;
  end;
  assert refused, 'an unknown A2 value is refused';
end $$;
