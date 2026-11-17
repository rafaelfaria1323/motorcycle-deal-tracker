-- A run keeps its step times as an object of parts; anything else is
-- refused, and older runs have none (N.118).
do $$
begin
  insert into public.collector_runs (started_at, status, steps_ms)
  values (now(), 'ok', '{"olx": {"fetch": 74000, "save": 3600}, "all": {"scores": 2100}}');
  assert (select (steps_ms -> 'olx' ->> 'save')::int from public.collector_runs
          where steps_ms is not null) = 3600,
    'the step times are kept';

  insert into public.collector_runs (started_at, status) values (now(), 'failed');
  assert (select steps_ms from public.collector_runs where status = 'failed') is null,
    'a run without a report has none';

  begin
    insert into public.collector_runs (started_at, status, steps_ms)
    values (now(), 'ok', '[1, 2]');
    assert false, 'a list is refused';
  exception when check_violation then
    null;
  end;
end;
$$;
