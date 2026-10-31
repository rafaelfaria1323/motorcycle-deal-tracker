-- F.6 (feature review 3.3 and 7.5): Alertas deletes every read alert in one
-- go, and two leftovers go.

-- Hides every read alert of the caller, as dismiss_alert does one at a
-- time: the rows stay, so the same event is never alerted again. Unread
-- alerts stay. Returns how many were hidden.
create function public.dismiss_read_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  perform public.require_account();

  update public.alerts a
  set dismissed_at = now(),
      notified_at = coalesce(a.notified_at, now())
  where a.user_id = (select auth.uid())
    and a.read_at is not null
    and a.dismissed_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.dismiss_read_alerts() from public, anon, authenticated;
grant execute on function public.dismiss_read_alerts() to authenticated;

-- Alerts are hidden through dismiss_alert; the delete grant this policy
-- served went in 20261024170000_tighten_api_grants.sql.
drop policy "Users delete their own alerts" on public.alerts;

-- pending_notifications without to_telegram: nothing has read it since
-- the alerts stopped going to Telegram (2026-10-21), and it cost an
-- app_admins lookup per alert. The collector reads the other columns by
-- name, so the code on main is unaffected.
drop function public.pending_notifications(integer, timestamptz);

create function public.pending_notifications(
  p_limit integer default 200,
  p_at timestamptz default null
)
returns table (
  alert_id    uuid,
  user_id     uuid,
  listing_id  uuid,
  type        public.alert_type,
  old_price   numeric,
  new_price   numeric,
  brand       text,
  model       text,
  year        integer,
  mileage     integer,
  price       numeric,
  deal_score  smallint,
  location    text,
  url         text,
  created_at  timestamptz,
  my_colour   boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.user_id, l.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text,
         a.created_at,
         public.likes_colour(a.user_id, l.motorcycle_id, l.colour)
  from public.alerts a
  join public.listings l on l.id = a.listing_id
  join auth.users u on u.id = a.user_id
  where a.notified_at is null
    and not coalesce(u.is_anonymous, false)
    and (p_at is null or not public.account_quiet_at(a.user_id, p_at))
  order by a.created_at
  limit p_limit
$$;
revoke all on function public.pending_notifications(integer, timestamptz)
  from public, anon, authenticated;
