-- The cards' market position (F.7): the percentage the listing page's
-- explanation reads, as one computed field.
insert into public.listings (source, source_listing_id, url, brand, model, price, score_breakdown)
values
  ('manual', 'mp-below', 'https://example.com/mp-below', 'Yamaha', 'MT-07', 6400,
   '{"pct_below_market": 8.04, "market_listing_count": 12}'),
  ('manual', 'mp-above', 'https://example.com/mp-above', 'Yamaha', 'MT-07', 7400,
   '{"pct_below_market": -5.36, "market_listing_count": 3}'),
  ('manual', 'mp-few', 'https://example.com/mp-few', 'Yamaha', 'MT-07', 6400,
   '{"pct_below_market": 20, "market_listing_count": 2}'),
  ('manual', 'mp-damaged', 'https://example.com/mp-damaged', 'Yamaha', 'MT-07', 5000,
   '{"pct_below_market": 25, "market_listing_count": 9, "damage_allowance": 0.15,
     "damaged_value": 5700, "pct_below_damaged_value": 12.3}'),
  ('manual', 'mp-placeholder', 'https://example.com/mp-placeholder', 'Yamaha', 'MT-07', 1,
   '{"pct_below_market": 99, "market_listing_count": 9}'),
  ('manual', 'mp-none', 'https://example.com/mp-none', 'Yamaha', 'MT-07', 6400, null);

do $$
begin
  assert (select l.market_position = 8.0 from public.listings l
          where source_listing_id = 'mp-below'), 'below the estimate, one decimal';
  assert (select l.market_position = -5.4 from public.listings l
          where source_listing_id = 'mp-above'), 'above it is negative';
  assert (select l.market_position is null from public.listings l
          where source_listing_id = 'mp-few'), 'nothing below 3 comparables';
  assert (select l.market_position = 12.3 from public.listings l
          where source_listing_id = 'mp-damaged'), 'a damaged bike: its damaged value';
  assert (select l.market_position is null from public.listings l
          where source_listing_id = 'mp-placeholder'), 'nothing for a placeholder price';
  assert (select l.market_position is null from public.listings l
          where source_listing_id = 'mp-none'), 'nothing before scoring';
  assert has_function_privilege('anon', 'public.market_position(public.listings)', 'execute');
end $$;

-- Saved choices made before the field get it, once.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f1');
insert into public.listing_card_preferences (user_id, visible_fields)
values ('00000000-0000-0000-0000-0000000000f1', array['year', 'market_position']);
do $$
begin
  assert (select visible_fields @> array['market_position']
          from public.listing_card_preferences
          where user_id = '00000000-0000-0000-0000-0000000000f1'),
    'the field is a known one';
end $$;
