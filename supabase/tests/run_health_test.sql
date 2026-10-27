-- A run can be partial and keeps how long its scoring took; any other
-- status is still refused.
do $$
begin
  insert into public.collector_runs (started_at, status, scoring_ms)
  values (now(), 'partial', 41230);
  assert (select scoring_ms from public.collector_runs where status = 'partial') = 41230,
    'the scoring time is kept';

  insert into public.collector_runs (started_at, status) values (now(), 'ok');
  assert (select scoring_ms from public.collector_runs where status = 'ok') is null,
    'older runs have none';

  begin
    insert into public.collector_runs (started_at, status) values (now(), 'unknown');
    assert false, 'an unknown status is refused';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.collector_runs (started_at, status, scoring_ms)
    values (now(), 'ok', -1);
    assert false, 'a negative time is refused';
  exception when check_violation then
    null;
  end;
end;
$$;
