-- Recall notifications (N.87): a recall stored after an account added its
-- bike or favourite, of that model and year, published in the last 60
-- days, is told once per account, outside quiet hours; the computed
-- fields give a model's and an owned bike's recalls.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', false),
  ('00000000-0000-0000-0000-0000000000e2', false),
  ('00000000-0000-0000-0000-0000000000e3', true);

insert into public.safety_gate_reports (reference, url, published_on)
values ('Report-2026-45',
        'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/detail/xml/1',
        '2026-11-10');

-- e1 owns a 2021 MT-07 and an R7, and keeps a 2021 MT-07 ad as a
-- favourite; e2 keeps the same ad; e3 (anonymous) owns an MT-07.
insert into public.owned_bikes (id, user_id, motorcycle_id, year, price_paid, created_at)
select v.id::uuid, v.owner::uuid, m.id, v.year, 6500, '2026-11-01'
from (values
  ('00000000-0000-0000-0000-00000000b0e1', '00000000-0000-0000-0000-0000000000e1', 'yamaha-mt-07', 2021),
  ('00000000-0000-0000-0000-00000000b0e2', '00000000-0000-0000-0000-0000000000e1', 'yamaha-r7', 2022),
  ('00000000-0000-0000-0000-00000000b0e3', '00000000-0000-0000-0000-0000000000e3', 'yamaha-mt-07', 2021)
) v(id, owner, slug, year)
join public.motorcycles m on m.slug = v.slug;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, year, price)
select 'olx', 'rn' || g, 'https://x/rn' || g, m.id, m.brand, m.model, 2021, 6500
from public.motorcycles m, generate_series(1, 2) g
where m.slug = 'yamaha-mt-07';

insert into public.listing_favourites (user_id, listing_id, created_at)
select u::uuid, l.id, '2026-11-01'
from public.listings l,
     unnest(array['00000000-0000-0000-0000-0000000000e1',
                  '00000000-0000-0000-0000-0000000000e2']) u
where l.source_listing_id = 'rn1';

-- An MT-07 recall for 2020-2022 bikes, one for 2015-2016 bikes, an old
-- one (published 2025) and one stored before everything was added.
insert into public.vehicle_recalls (case_number, report, published_on, brand, name,
                                    from_year, to_year, recall_code, danger_en,
                                    danger_pt, match_keys, stored_at)
values
  ('A12/001', 'Report-2026-45', '2026-11-10', 'Yamaha', 'MT-07', 2020, 2022, '3P0',
   'The brake hose may leak.', 'O tubo do travão pode verter.', '{mt07}', '2026-11-12'),
  ('A12/002', 'Report-2026-45', '2026-11-10', 'Yamaha', 'MT-07', 2015, 2016, null,
   'Old frames.', 'Quadros antigos.', '{mt07}', '2026-11-12'),
  ('A12/003', 'Report-2026-45', '2025-06-10', 'Yamaha', 'MT-07', null, null, null,
   'Old news.', 'Notícia antiga.', '{mt07}', '2026-11-12'),
  ('A12/004', 'Report-2026-45', '2026-11-10', 'Yamaha', 'MT-07', null, null, null,
   'Stored first.', 'Guardada antes.', '{mt07}', '2026-10-01');

do $$
declare
  e1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  e2 constant uuid := '00000000-0000-0000-0000-0000000000e2';
  at constant timestamptz := '2026-11-13 12:00+00';
  r record;
begin
  -- A row stored later gets the time it was stored.
  assert (select stored_at from public.vehicle_recalls where case_number = 'A12/001')
         = '2026-11-12', 'stored_at as given';

  -- Only the 2020-2022 recall: once for e1 (its own bike first), once for
  -- e2 (its favourite); not the anonymous account, the R7, the other
  -- years, the old one or the one stored before.
  assert (select count(*) from public.pending_recall_notices(at)) = 2,
    format('two notices, got %s', (select count(*) from public.pending_recall_notices(at)));

  select * into r from public.pending_recall_notices(at) where user_id = e1;
  assert r.case_number = 'A12/001' and r.bike_id = '00000000-0000-0000-0000-00000000b0e1'
         and r.listing_id is null, 'e1 hears of its own bike';
  assert r.brand = 'Yamaha' and r.model = 'MT-07' and r.year = 2021
         and r.recall_name = 'MT-07' and r.recall_code = '3P0'
         and r.danger_pt = 'O tubo do travão pode verter.', 'the recall';

  select * into r from public.pending_recall_notices(at) where user_id = e2;
  assert r.bike_id is null
         and r.listing_id = (select id from public.listings where source_listing_id = 'rn1'),
    'e2 hears of its favourite';

  -- A gone favourite tells nothing.
  update public.listings set status = 'removed' where source_listing_id = 'rn1';
  assert not exists (select 1 from public.pending_recall_notices(at) where user_id = e2),
    'gone favourites are left out';
  update public.listings set status = 'active' where source_listing_id = 'rn1';

  -- Midnight is in the default quiet hours.
  assert not exists (select 1 from public.pending_recall_notices('2026-11-14 00:00+00')),
    'quiet hours hold the notices';

  -- Sixty days on, nothing.
  assert not exists (select 1 from public.pending_recall_notices('2027-01-10 12:00+00')),
    'only recent recalls';

  -- Marked once; a second mark changes nothing.
  assert public.mark_recall_noticed(e1, 'A12/001'), 'first mark';
  assert not public.mark_recall_noticed(e1, 'A12/001'), 'second mark';
  assert not exists (select 1 from public.pending_recall_notices(at) where user_id = e1),
    'told once';
  assert exists (select 1 from public.pending_recall_notices(at) where user_id = e2),
    'the other account still waits';

  -- Computed fields: the model's four, the owned bike's with applies.
  assert jsonb_array_length((select public.recalls(m) from public.motorcycles m
                             where slug = 'yamaha-mt-07')) = 4, 'the model''s recalls';
  assert (select count(*) from jsonb_array_elements(
            (select public.recalls(b) from public.owned_bikes b
             where id = '00000000-0000-0000-0000-00000000b0e1')) e
          where (e ->> 'applies')::boolean) = 3, 'the bike''s: all but 2015-2016';

  -- Push-test kind.
  assert pg_get_functiondef('public.start_workflow(text, text)'::regprocedure) like '%''recall''%',
    'push-test kind recall';
end $$;

-- No API access to the notices or the functions.
do $$
begin
  assert not has_table_privilege('authenticated', 'public.recall_notices', 'select');
  assert not has_function_privilege('authenticated', 'public.pending_recall_notices(timestamptz)', 'execute');
  assert not has_function_privilege('anon', 'public.mark_recall_noticed(uuid, text)', 'execute');
  assert has_function_privilege('anon', 'public.recalls(public.motorcycles)', 'execute');
end $$;
