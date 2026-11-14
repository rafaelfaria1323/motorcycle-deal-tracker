-- The outside APIs' calls (N.101): the weekly steps that ask API Ninjas
-- (model specifications, N.76) and Gemini (the description check, N.55)
-- count the requests they made and store them per Lisbon day, so admins
-- see in "Estado da recolha" how much of each free tier a month takes.
-- The providers' own figures need the key, which only the workflows hold.
create table public.api_usage (
  service text not null check (service in ('api_ninjas', 'gemini')),
  day date not null,
  requests integer not null check (requests >= 0),
  primary key (service, day)
);

comment on table public.api_usage is
  'Requests made to outside APIs per Lisbon day (N.101). No API access: record_api_usage (collector), api_usage (admins).';

alter table public.api_usage enable row level security;
revoke all on public.api_usage from anon, authenticated;

-- Adds one run's requests to today's (Lisbon) count; rows older than 13
-- months go.
create function public.record_api_usage(p_service text, p_requests integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Lisbon')::date;
begin
  if p_requests is null or p_requests <= 0 then
    return;
  end if;
  insert into public.api_usage (service, day, requests)
  values (p_service, v_today, p_requests)
  on conflict (service, day) do update
    set requests = public.api_usage.requests + excluded.requests;
  delete from public.api_usage where day < v_today - interval '13 months';
end;
$$;

revoke all on function public.record_api_usage(text, integer)
  from public, anon, authenticated;
grant execute on function public.record_api_usage(text, integer) to service_role;

-- Per service (both, used or not): this Lisbon month's requests, last
-- month's, and the last day with any. Admins only.
create function public.api_usage()
returns table (
  service text,
  month_requests integer,
  last_month_requests integer,
  last_used_on date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', now() at time zone 'Europe/Lisbon')::date;
begin
  perform public.require_admin();
  return query
  select s.service,
         coalesce(sum(u.requests) filter (where u.day >= v_month), 0)::integer,
         coalesce(sum(u.requests) filter (
           where u.day >= v_month - interval '1 month' and u.day < v_month), 0)::integer,
         max(u.day)
  from unnest(array['api_ninjas', 'gemini']) s(service)
  left join public.api_usage u on u.service = s.service
  group by s.service
  order by s.service;
end;
$$;

revoke all on function public.api_usage() from public, anon;
grant execute on function public.api_usage() to authenticated;
