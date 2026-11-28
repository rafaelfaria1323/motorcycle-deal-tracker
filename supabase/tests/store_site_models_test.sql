-- N.134: the sites' brand and model lists in one call, writing only rows
-- that are new, renamed or a day old.

delete from public.site_models where source = 'olx' and make_id = 'test-make';

do $$
declare
  models jsonb := '[
    {"source": "olx", "make_id": "test-make", "make_name": "Test", "model_id": "a", "model_name": "A", "ads": 3},
    {"source": "olx", "make_id": "test-make", "make_name": "Test", "model_id": "b", "model_name": "B", "ads": null},
    {"source": "olx", "make_id": "test-make", "make_name": "Test", "model_id": "b", "model_name": "B", "ads": null},
    {"source": "olx", "make_id": null, "make_name": "Test", "model_id": "c", "model_name": "C"}
  ]';
  n integer;
begin
  n := public.store_site_models('olx', models);
  assert n = 2, format('two new rows, repeats and rows without ids left out: %s', n);
  assert (select ads from public.site_models where make_id = 'test-make' and model_id = 'a') = 3;

  n := public.store_site_models('olx', models);
  assert n = 0, format('the same list again writes nothing: %s', n);

  n := public.store_site_models('olx',
    jsonb_set(models, '{0,model_name}', '"A Renamed"'));
  assert n = 1, format('a renamed model is written: %s', n);
  assert (select model_name from public.site_models
          where make_id = 'test-make' and model_id = 'a') = 'A Renamed';

  update public.site_models set seen_at = now() - interval '2 days', ads = 1
  where make_id = 'test-make' and model_id = 'b';
  n := public.store_site_models('olx',
    jsonb_set(models, '{1,ads}', '7'));
  assert n = 2, format('the day-old row refreshes, the renamed one goes back: %s', n);
  assert (select (ads, seen_at = now()) from public.site_models
          where make_id = 'test-make' and model_id = 'b') = row(7, true);

  assert public.store_site_models('olx', null) = 0, 'no list';
end $$;

do $$
begin
  assert not has_function_privilege('authenticated', 'public.store_site_models(text, jsonb)', 'execute');
  assert not has_function_privilege('anon', 'public.store_site_models(text, jsonb)', 'execute');
end $$;
