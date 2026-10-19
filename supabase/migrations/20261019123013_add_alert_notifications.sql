-- When an alert was pushed to the owner's phone. Null = not sent yet.
alter table public.alerts add column notified_at timestamptz;

-- Everything that exists today counts as already sent: no flood on day one.
update public.alerts set notified_at = now();

-- Alerts still to send, oldest first, with what the message needs.
-- Only real accounts: anonymous sessions' alerts are never pushed.
create function public.pending_notifications(p_limit integer default 20)
returns table (
  alert_id    uuid,
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
  url         text
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.type, a.old_price::numeric, a.new_price::numeric,
         l.brand::text, l.model::text, l.year::integer, l.mileage::integer,
         l.price::numeric, l.deal_score::smallint, l.location::text, l.url::text
  from public.alerts a
  join public.listings l on l.id = a.listing_id
  join auth.users u on u.id = a.user_id
  where a.notified_at is null
    and not coalesce(u.is_anonymous, false)
  order by a.created_at
  limit p_limit
$$;

create function public.mark_alerts_notified(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.alerts
  set notified_at = now()
  where id = any(p_ids)
    and notified_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.pending_notifications(integer)
  from public, anon, authenticated;
revoke all on function public.mark_alerts_notified(uuid[])
  from public, anon, authenticated;