-- N.107 (20261115140000_typed_ad_score.sql): a typed ad is scored as a
-- stored ad with the same facts would be.
do $$
declare
  mt uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  stored record;
  typed record;
  r record;
begin
  update public.motorcycles
  set new_price_reference = null, new_price_from_ads = null
  where id = mt;

  -- Six others at 8 000 € and a private ad at 7 000 € with the same facts
  -- as the typed one.
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, seller_type,
                               location, description)
  select 'olx', 'ta' || g, 'https://x/ta' || g, mt, 'Yamaha', 'MT-07',
         2021, 20000, 8000, 'dealer', 'Lisboa',
         'Mota em bom estado, revisões feitas no concessionário.'
  from generate_series(1, 6) g;
  insert into public.listings (source, source_listing_id, url, motorcycle_id,
                               brand, model, year, mileage, price, seller_type,
                               location, description, registrations, service_book)
  values ('olx', 'ta-me', 'https://x/ta-me', mt, 'Yamaha', 'MT-07',
          2021, 20000, 7000, 'private', 'Porto',
          'Vendo a minha MT-07 com quickshifter e escape Akrapovic, sempre na garagem.',
          1, true);
  perform public.recalculate_deal_scores();

  select deal_score, risk_score, score_breakdown into stored
  from public.listings where source_listing_id = 'ta-me';
  select * into typed from public.typed_ad_score(
    mt, 2021, 20000, 7000, true, 1, true, false, null,
    'Vendo a minha MT-07 com quickshifter e escape Akrapovic, sempre na garagem.');

  assert typed.deal_score = stored.deal_score,
    format('the same Deal Score: typed %s, stored %s', typed.deal_score, stored.deal_score);
  assert typed.risk_score = stored.risk_score,
    format('the same Risk Score: typed %s, stored %s', typed.risk_score, stored.risk_score);
  assert (typed.breakdown->>'market_listing_count')::int = 7
     and (typed.breakdown->>'market_price')::numeric = 8000
     and (typed.breakdown->>'pct_below_market')::numeric = 12.5,
    format('the market: %s', typed.breakdown);
  assert typed.breakdown->'valued_extras' ? 'quickshifter'
     and typed.breakdown->'risk_reasons' ? 'first_owner',
    format('extras and reasons: %s', typed.breakdown);

  -- An accident the person reports: priced against the damaged value, capped.
  select * into r from public.typed_ad_score(mt, 2021, 20000, 5000, true, null, null,
                                             false, 'accident', null);
  assert r.breakdown->'risk_reasons' ? 'possible_accident'
     and (r.breakdown->>'damaged_value')::numeric = 6800
     and r.deal_score <= 79, format('accident: %s %s', r.deal_score, r.breakdown);
  -- A fall: scratches, no allowance.
  select * into r from public.typed_ad_score(mt, 2021, 20000, 7000, true, null, null,
                                             false, 'dropped', null);
  assert r.breakdown->'risk_reasons' ? 'cosmetic_damage'
     and r.breakdown->>'damaged_value' is null, format('fall: %s', r.breakdown);
  -- Under warranty, no description, a dealer: no "thin description".
  select * into r from public.typed_ad_score(mt, 2021, 20000, 7000, false, null, null,
                                             true, null, null);
  assert r.breakdown->'risk_reasons' ? 'under_warranty'
     and not r.breakdown->'risk_reasons' ? 'thin_description'
     and not r.breakdown->'risk_reasons' ? 'no_location', format('warranty: %s', r.breakdown);
  -- A private seller's two words: thin.
  select * into r from public.typed_ad_score(mt, 2021, 20000, 7000, true, null, null,
                                             false, null, 'Vendo mota');
  assert r.breakdown->'risk_reasons' ? 'thin_description', format('thin: %s', r.breakdown);

  -- Too few comparables: no price slice, at most 70.
  select * into r from public.typed_ad_score(
    (select id from public.motorcycles where slug = 'yamaha-r1'), 2021, 20000, 7000, true);
  assert (r.breakdown->>'market_listing_count')::int = 0
     and r.deal_score <= 70 and not r.breakdown->'scores' ? 'price',
    format('no comparables: %s %s', r.deal_score, r.breakdown);

  -- A placeholder price, or an unknown model: no score.
  -- B.1: the title is read as a stored ad's version: an A2 version and
  -- equipment it names count though the text says nothing of them.
  select * into r from public.typed_ad_score(mt, 2021, 20000, 7000, true, null, null,
    false, null, 'Mota em bom estado.', p_variant => 'MT-07 35 kW A2 com quickshifter');
  assert r.breakdown->'risk_reasons' ? 'a2_limited'
     and r.breakdown->'valued_extras' ? 'quickshifter',
    format('the title read: %s', r.breakdown);
  select * into r from public.typed_ad_score(mt, 2021, 20000, 7000, true, null, null,
    false, null, 'Mota em bom estado.', p_variant => '  ');
  assert not r.breakdown->'risk_reasons' ? 'a2_limited',
    format('a blank title reads nothing: %s', r.breakdown);

  assert not exists (select from public.typed_ad_score(mt, 2021, 20000, 1, true)),
    'a placeholder price';
  assert not exists (select from public.typed_ad_score(gen_random_uuid(), 2021, 20000, 7000, true)),
    'an unknown model';

  assert has_function_privilege('anon',
           'public.typed_ad_score(uuid, integer, integer, numeric, boolean, integer, boolean, boolean, text, text, integer, integer, text)',
           'execute'),
    'visitors can score a typed ad';
end;
$$;

-- As a visitor.
set local role anon;
do $$
begin
  assert exists (select from public.typed_ad_score(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'), 2021, 20000, 7000, true)),
    'scored for a visitor';
end;
$$;
