-- The migration gave catalog models named with an engine size, but added
-- without one, the size in their name; models with their own keep it.
do $$
begin
  assert not exists (
    select 1 from public.motorcycles
    where engine_cc_min is null and engine_cc_max is null
      and public.engine_range_from_name(model) is not null),
    'every model named with a size has engine limits';
  assert public.engine_range_from_name('Forza 350cc') = int4range(315, 385, '[]');
  assert public.engine_range_from_name('MT-07') is null;
  assert public.engine_range_from_name('Tracer 7') is null;
  assert public.engine_range_from_name('Vespa 30') is null, 'under 50 is not an engine size';
  assert public.engine_range_from_name('Africa Twin 1100') = int4range(990, 1210, '[]');
end $$;
