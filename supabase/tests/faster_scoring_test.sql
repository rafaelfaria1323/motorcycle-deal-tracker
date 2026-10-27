-- The scoring run's speed settings (20261027090000_faster_scoring.sql): JIT
-- off in the function, 60 s for the collector's role, and extras (now
-- worked out once per listing) still in the score and its breakdown.

do $$
declare
  config text[] := (select p.proconfig from pg_catalog.pg_proc p
                    where p.oid = 'public.recalculate_deal_scores()'::regprocedure);
  role_config text[] := (select s.setconfig from pg_catalog.pg_db_role_setting s
                         where s.setrole = 'service_role'::regrole
                           and s.setdatabase = 0);
begin
  assert 'jit=off' = any(config), format('jit off, got %s', config);
  assert 'search_path=""' = any(config), format('search_path kept, got %s', config);
  assert 'statement_timeout=60s' = any(role_config),
    format('service_role timeout, got %s', role_config);
end $$;

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       2023, 6000, 7000, 'Porto', v.description, 'active'
from public.motorcycles m,
     (values
       ('qs',  'Com quickshifter e punhos aquecidos, revisões feitas.'),
       ('std', 'Revisões feitas, sempre na garagem.'),
       ('c1', null), ('c2', null), ('c3', null)
     ) v(sid, description)
where m.slug = 'yamaha-mt-07';

do $$
declare
  n integer := public.recalculate_deal_scores();
  qs record;
  std record;
begin
  assert n >= 5, format('listings scored, got %s', n);
  select deal_score, score_breakdown b into qs
  from public.listings where source_listing_id = 'qs';
  select deal_score, score_breakdown b into std
  from public.listings where source_listing_id = 'std';
  assert qs.b -> 'extras' ? 'quickshifter', format('extras, got %s', qs.b -> 'extras');
  assert qs.b -> 'valued_extras' ? 'heated_grips',
    format('valued extras, got %s', qs.b -> 'valued_extras');
  assert qs.deal_score = std.deal_score + 2,
    format('one point per valued extra: %s vs %s', qs.deal_score, std.deal_score);
end $$;

-- The description's signals are stored by the trigger, worked out again
-- only when the text changes, and read by the risk score.
do $$
declare
  signals text[];
  extras text[];
begin
  select text_signals, text_extras into signals, extras
  from public.listings where source_listing_id = 'qs';
  assert signals = '{}', format('no risk words, got %s', signals);
  assert extras @> array['quickshifter', 'heated_grips'], format('extras stored, got %s', extras);

  update public.listings
  set description = 'Caiu parada. Versão A2 limitada. Primeiro dono.'
  where source_listing_id = 'std';
  select text_signals into signals from public.listings where source_listing_id = 'std';
  assert signals = array['possible_accident', 'a2_limited', 'single_owner_in_text'],
    format('new text, new signals, got %s', signals);

  -- The same text written again (as every import does) keeps them.
  update public.listings set text_signals = array['needs_repair']
  where source_listing_id = 'qs';
  update public.listings set description = description, variant = variant
  where source_listing_id = 'qs';
  select text_signals into signals from public.listings where source_listing_id = 'qs';
  assert signals = array['needs_repair'], format('unchanged text kept, got %s', signals);
  assert (select reasons from public.listing_risk_scores r
          join public.listings l on l.id = r.listing_id
          where l.source_listing_id = 'qs') @> array['needs_repair'],
    'the risk reads the stored signals';

  -- Null (a refresh) is filled again.
  update public.listings set text_signals = null where source_listing_id = 'qs';
  select text_signals into signals from public.listings where source_listing_id = 'qs';
  assert signals = '{}', format('refreshed, got %s', signals);

  -- Rows not filled yet: worked out on the fly, same answer as risk_assessment.
  alter table public.listings disable trigger listings_text_signals;
  update public.listings set text_signals = null, text_extras = null
  where source_listing_id = 'std';
  alter table public.listings enable trigger listings_text_signals;
  assert (select reasons from public.listing_risk_scores r
          join public.listings l on l.id = r.listing_id
          where l.source_listing_id = 'std')
         = (select r.reasons from public.listings l
            left join public.listing_fair_prices f on f.listing_id = l.id,
            lateral public.risk_assessment(
              l.price, case when f.comparable_count >= 3 then f.fair_price end,
              l.year, l.mileage, l.description, l.location,
              true, false, null, null, null, null, 0, null, l.variant) r
            where l.source_listing_id = 'std'),
    'null signals worked out on the fly';
end $$;
