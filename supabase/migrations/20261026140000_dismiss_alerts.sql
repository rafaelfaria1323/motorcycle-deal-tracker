-- Keep event history so a dismissed alert is never generated again.
alter table public.alerts add column dismissed_at timestamptz;

create function public.dismiss_alert(p_alert uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  update public.alerts a
  set dismissed_at = coalesce(a.dismissed_at, now()),
      read_at = coalesce(a.read_at, now()),
      notified_at = coalesce(a.notified_at, now())
  where a.id = p_alert and a.user_id = (select auth.uid());

  if not found then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.dismiss_alert(uuid) from public, anon, authenticated;
grant execute on function public.dismiss_alert(uuid) to authenticated;
