-- Quiet hours: an account's alerts are not pushed between start_hour and
-- end_hour (Lisbon time); they stay pending and go with the first run
-- after the quiet hours end (08:00's collection by default). An account
-- without a row has the default: on, 23:00 to 08:00, because the 00:00
-- collection pushed alerts at midnight.
create table public.quiet_hours (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  enabled boolean not null default true,
  start_hour smallint not null default 23,
  end_hour smallint not null default 8,
  updated_at timestamptz not null default now(),
  constraint quiet_hours_hours check (
    start_hour between 0 and 23 and end_hour between 0 and 23
    and start_hour <> end_hour
  )
);

alter table public.quiet_hours enable row level security;

revoke all on public.quiet_hours from public, anon, authenticated;
grant select, insert, update on public.quiet_hours to authenticated;

create policy "Accounts manage their own quiet hours"
  on public.quiet_hours
  for all to authenticated
  using (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  )
  with check (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  );

-- Whether an hour of the day (0-23) falls in the quiet hours from p_start
-- to p_end (end excluded); they may wrap midnight (23 to 8).
create function public.in_quiet_hours(p_start integer, p_end integer, p_hour integer)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_start < p_end then p_hour >= p_start and p_hour < p_end
    else p_hour >= p_start or p_hour < p_end
  end
$$;

-- Whether the account is in its quiet hours at p_at (Lisbon time; the
-- default when it has no row).
create function public.account_quiet_at(p_user uuid, p_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(q.enabled, true)
     and public.in_quiet_hours(
           coalesce(q.start_hour, 23), coalesce(q.end_hour, 8),
           extract(hour from p_at at time zone 'Europe/Lisbon')::integer)
  from (select 1) one
  left join public.quiet_hours q on q.user_id = p_user
$$;
revoke all on function public.account_quiet_at(uuid, timestamptz)
  from public, anon, authenticated;

-- p_at: the collector's time; alerts of accounts in their quiet hours then
-- are left out (still pending). Null leaves nobody out.
drop function public.pending_notifications(integer);

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
  to_telegram boolean,
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
         exists (select 1 from public.app_admins ad where ad.user_id = a.user_id),
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
