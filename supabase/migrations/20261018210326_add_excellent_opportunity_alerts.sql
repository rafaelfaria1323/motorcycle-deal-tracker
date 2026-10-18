-- When a listing last crossed up to "excellent". Null = not excellent now.
alter table public.listings add column excellent_since timestamptz;

-- Listings that are already excellent when tracking begins count as excellent
-- "since forever", so they never alert. (80 is the default threshold below.)
update public.listings
set excellent_since = '-infinity'
where deal_score >= 80;

-- One excellent-opportunity alert per person per listing, however often its
-- score crosses the line.
create unique index alerts_one_excellent_per_user
  on public.alerts (user_id, listing_id)
  where type = 'excellent_opportunity';

-- Alerts for listings that have reached p_threshold (and are not suspiciously
-- risky) since a matching search wanting them was saved. Safe to run
-- repeatedly. Run it after scoring.
create function public.generate_excellent_opportunity_alerts(
  p_threshold integer default 80,
  p_max_risk  integer default 50
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  -- Remember the moment a listing becomes excellent...
  update public.listings
  set excellent_since = now()
  where excellent_since is null
    and deal_score >= p_threshold;

  -- ...and forget it when it falls back, so a later climb counts as new.
  update public.listings
  set excellent_since = null
  where excellent_since is not null
    and (deal_score is null or deal_score < p_threshold);

  insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
  select distinct on (s.user_id, l.id)
         s.user_id, s.id, l.id, 'excellent_opportunity'::public.alert_type,
         l.price
  from public.saved_search_matches m
  join public.saved_searches s on s.id = m.saved_search_id
  join public.listings l on l.id = m.listing_id
  where s.is_active
    and s.notify_excellent_deal
    and l.deal_score >= p_threshold
    and coalesce(l.risk_score, 0) < p_max_risk
    and l.excellent_since > s.created_at
  order by s.user_id, l.id, s.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.generate_excellent_opportunity_alerts(integer, integer)
  from public, anon, authenticated;

-- The collector's single entry point now creates all three kinds.
create or replace function public.generate_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.generate_new_listing_alerts()
       + public.generate_price_reduction_alerts()
       + public.generate_excellent_opportunity_alerts();
end;
$$;