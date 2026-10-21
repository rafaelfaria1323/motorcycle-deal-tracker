-- Bug hunt, part 2: data fixes.

-- 1. Old events alerted when a listing starts matching a saved search
-- later (the account follows the model, lowers its first year, a better
-- matching rule, a duplicate mark cleared): only events of the last day
-- count now, besides coming after the search was created. The collector
-- makes alerts at the end of the run that imports the events, every 4
-- hours, so a day leaves room for a failed run.
create or replace function public.generate_new_listing_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
  select distinct on (s.user_id, l.id)
         s.user_id, s.id, l.id, 'new_listing'::public.alert_type, l.price
  from public.saved_search_matches m
  join public.saved_searches s on s.id = m.saved_search_id
  join public.listings l on l.id = m.listing_id
  where s.is_active
    and s.notify_new_listing
    and l.first_seen_at > greatest(s.created_at, now() - interval '1 day')
  order by s.user_id, l.id, s.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.generate_price_reduction_alerts(
  p_min_drop_pct numeric default 1
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (
    user_id, saved_search_id, listing_id, type,
    old_price, new_price, price_history_id
  )
  select distinct on (s.user_id, c.history_id)
         s.user_id, s.id, c.listing_id, 'price_reduction'::public.alert_type,
         c.old_price, c.new_price, c.history_id
  from (
    select h.id as history_id,
           h.listing_id,
           h.observed_at,
           h.price as new_price,
           lag(h.price) over (
             partition by h.listing_id order by h.observed_at, h.id
           ) as old_price
    from public.listing_price_history h
  ) c
  join public.saved_search_matches m on m.listing_id = c.listing_id
  join public.saved_searches s on s.id = m.saved_search_id
  where c.old_price is not null
    and c.new_price < c.old_price
    and (c.old_price - c.new_price) / c.old_price * 100 >= p_min_drop_pct
    and s.is_active
    and s.notify_price_reduction
    and c.observed_at > greatest(s.created_at, now() - interval '1 day')
  order by s.user_id, c.history_id, s.created_at
  on conflict do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- 2. A listing removed, back on the market and removed again never alerted
-- the second time (one removal alert per person and listing, ever). Now one
-- per removal: none yet since the listing was last marked removed
-- (mark_removed_listings stamps last_checked_at, which only a later sighting
-- or removal changes). Removals of the last day only, so the change doesn't
-- send a burst of old ones.
drop index public.alerts_one_removed_per_user;
create index alerts_removed_user_listing_idx
  on public.alerts (user_id, listing_id, created_at)
  where type = 'listing_removed';

create or replace function public.generate_listing_removed_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.alerts (user_id, saved_search_id, listing_id, type, new_price)
  select distinct on (a.user_id, a.listing_id)
         a.user_id, s.id, a.listing_id, 'listing_removed'::public.alert_type,
         l.price
  from public.alerts a
  join public.saved_searches s on s.id = a.saved_search_id
  join public.listings l on l.id = a.listing_id
  where a.type <> 'listing_removed'
    and s.is_active
    and s.notify_listing_removed
    and l.status = 'removed'
    and l.last_checked_at > now() - interval '1 day'
    and not exists (select 1 from public.alerts r
                    where r.user_id = a.user_id
                      and r.listing_id = a.listing_id
                      and r.type = 'listing_removed'
                      and r.created_at >= l.last_checked_at)
  order by a.user_id, a.listing_id, a.created_at;

  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.generate_favourite_alerts(p_min_drop_pct numeric default 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  drops   integer;
  removed integer;
begin
  insert into public.alerts (
    user_id, listing_id, type, old_price, new_price, price_history_id
  )
  select f.user_id, c.listing_id, 'price_reduction'::public.alert_type,
         c.old_price, c.new_price, c.history_id
  from (
    select h.id as history_id,
           h.listing_id,
           h.observed_at,
           h.price as new_price,
           lag(h.price) over (
             partition by h.listing_id order by h.observed_at, h.id
           ) as old_price
    from public.listing_price_history h
  ) c
  join public.listing_favourites f on f.listing_id = c.listing_id
  where c.old_price is not null
    and c.new_price < c.old_price
    and (c.old_price - c.new_price) / c.old_price * 100 >= p_min_drop_pct
    and c.observed_at > f.created_at
  on conflict do nothing;
  get diagnostics drops = row_count;

  insert into public.alerts (user_id, listing_id, type, new_price)
  select f.user_id, l.id, 'listing_removed'::public.alert_type, l.price
  from public.listing_favourites f
  join public.listings l on l.id = f.listing_id
  where l.status = 'removed'
    and l.last_checked_at > f.created_at
    and l.last_checked_at > now() - interval '1 day'
    and not exists (select 1 from public.alerts r
                    where r.user_id = f.user_id
                      and r.listing_id = l.id
                      and r.type = 'listing_removed'
                      and r.created_at >= l.last_checked_at);
  get diagnostics removed = row_count;

  return drops + removed;
end;
$$;

-- 3. mark_duplicates cleared the marks of every listing, removed ones too,
-- but paired only live ones again: a gone duplicate counted as a gone bike
-- in the market figures, the weekly summary and the dealer figures. Now
-- only live listings' marks are worked out again; a removed listing keeps
-- the mark it had when it went.
create or replace function public.mark_duplicates(p_threshold integer default 70)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set duplicate_of = null, duplicate_score = null
  where status in ('active', 'price_changed')
    and (duplicate_of is not null or duplicate_score is not null);
  with live as (
    select * from public.listings
    where status in ('active', 'price_changed')
  ),
  pairs as (
    select
      b.id as dup_id,
      a.id as original_id,
      a.first_seen_at as original_seen,
      public.duplicate_similarity(
        a.mileage, b.mileage, a.price, b.price, a.location, b.location,
        a.description, b.description, a.seller_name, b.seller_name
      ) as score
    from live a
    join live b
      on a.motorcycle_id = b.motorcycle_id
     and a.year = b.year
     and (a.first_seen_at, a.id) < (b.first_seen_at, b.id)
    -- a dealer's identical new bikes are separate stock, not duplicates
    where not (a.source = b.source
               and coalesce(a.mileage, 0) < 500
               and coalesce(b.mileage, 0) < 500)
  ),
  best as (
    select distinct on (dup_id) dup_id, original_id, score
    from pairs
    where score >= p_threshold
    order by dup_id, original_seen, original_id
  )
  update public.listings l
  set duplicate_of = best.original_id,
      duplicate_score = best.score
  from best
  where l.id = best.dup_id;

  get diagnostics n = row_count;

  -- Chains: if C duplicates B and B duplicates A, C should point at A.
  for i in 1..5 loop
    update public.listings c
    set duplicate_of = p.duplicate_of
    from public.listings p
    where c.duplicate_of = p.id and p.duplicate_of is not null;
    exit when not found;
  end loop;

  perform public.mark_relists(p_threshold);

  return n;
end;
$$;

-- 4. The thin-description risk waited for the listing page to be read
-- (details_checked_at), which never happens on OLX: its search results
-- already hold the whole description.
create or replace view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.listing_fair_prices f on f.listing_id = l.id
left join public.listings prev on prev.id = l.relisted_from
cross join lateral public.risk_assessment(
  l.price,
  case when f.comparable_count >= 3 then f.fair_price end,
  l.year,
  l.mileage,
  l.description,
  l.location,
  l.details_checked_at is not null or l.source = 'olx',
  coalesce(l.seller_type::text = 'private', false),
  l.registrations,
  l.service_book,
  l.origin,
  l.warranty_until,
  (l.relisted_from is not null)::integer + (prev.relisted_from is not null)::integer,
  l.relisted_since
) r
where l.status in ('active', 'price_changed');

-- 5. Implausible mileage counted the age in calendar years: a bike
-- registered last year was one year old all this year, so 26 000 km in
-- October read as more than a year's riding.
create or replace function public.risk_assessment(
  p_price          numeric,
  p_market_price   numeric,
  p_year           integer,
  p_mileage        integer,
  p_description    text,
  p_location       text,
  p_details_known  boolean default false,
  p_private_seller boolean default false,
  p_registrations  integer default null,
  p_service_book   boolean default null,
  p_origin         text    default null,
  p_warranty_until date    default null,
  p_relists        integer default 0,
  p_on_sale_since  timestamptz default null
)
returns table (risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (p_market_price - p_price) / p_market_price * 100
    end as below
  ),
  signals(code, points) as (
    select 'price_far_below_market'::text, 45 from pct where below >= 25
    union all
    select 'price_below_market', 25 from pct where below >= 15 and below < 25
    union all
    select 'possible_accident', 30
    where public.mentions_accident(p_description)
    union all
    select 'no_mileage', 15 where p_mileage is null
    union all
    select 'no_year', 10 where p_year is null
    union all
    -- A placeholder ("0", "1", "10") on a bike three or more years old, or
    -- far more than anyone rides in a year (bikes average 3-6 000 km). The
    -- age counts from mid-year registration in days, at least one year, as
    -- expected_mileage does.
    select 'suspicious_mileage', 10
    where p_mileage is not null and p_year is not null
      and (
        (p_mileage < 100
          and p_year <= extract(year from current_date)::integer - 3)
        or p_mileage::numeric
           / greatest(1, public.decimal_year() - (p_year + 0.5))
           > 25000
      )
    union all
    -- Only meaningful once the page was read, and only for private sellers:
    -- dealers rarely write more than boilerplate.
    select 'thin_description', 10
    where p_details_known and p_private_seller
      and char_length(btrim(coalesce(p_description, ''))) < 40
    union all
    select 'no_location', 5
    where nullif(btrim(coalesce(p_location, '')), '') is null
    union all
    select 'many_owners', 15 where p_registrations >= 3
    union all
    select 'no_service_book', 10 where p_service_book = false
    union all
    select 'imported', 10 where p_origin is not null and p_origin <> 'national'
    union all
    -- The text says something else than the ad's own fields.
    select c, 10 from unnest(public.text_contradictions(
      p_description, p_year, p_mileage, p_origin, p_service_book)) c
    union all
    -- A bike put up again after its ad went (mark_relists): it did not sell
    -- at that price. More when it happened twice or the bike has been on
    -- sale for over 90 days counting the earlier ads.
    select 'relisted_often', 10
    where p_relists >= 2
       or (p_relists = 1 and p_on_sale_since < now() - interval '90 days')
    union all
    select 'relisted', 5
    where p_relists = 1
      and (p_on_sale_since is null or p_on_sale_since >= now() - interval '90 days')
    union all
    select 'first_owner', -5 where p_registrations = 1
    union all
    select 'service_book', -5 where p_service_book
    union all
    select 'under_warranty', -10 where p_warranty_until >= current_date
  )
  select
    greatest(0, least(100, coalesce(sum(points), 0)))::smallint,
    coalesce(array_agg(code order by points desc, code), '{}'::text[])
  from signals
$$;

-- 6. A listing page's publication date replaced the stored one; the
-- earliest is kept, as apply_listing_dates does (least ignores nulls).
create or replace function public.apply_listing_details(p_source text, p_details jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set description            = coalesce(d.description, l.description),
      registrations          = coalesce(d.registrations, l.registrations),
      service_book           = coalesce(d.service_book, l.service_book),
      origin                 = coalesce(d.origin, l.origin),
      warranty_until         = coalesce(d.warranty_until, l.warranty_until),
      dealer_warranty_months = coalesce(d.dealer_warranty_months,
                                        l.dealer_warranty_months),
      published_at           = least(d.published_at, l.published_at),
      details_checked_at     = now()
  from jsonb_to_recordset(p_details) as d(
    source_listing_id      text,
    description            text,
    registrations          smallint,
    service_book           boolean,
    origin                 text,
    warranty_until         date,
    dealer_warranty_months smallint,
    published_at           timestamptz
  )
  where l.source = p_source
    and l.source_listing_id = d.source_listing_id;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- A listing page that could not be read (gone, unreadable, redirected to
-- another ad) is asked again only after the listings never tried, so a few
-- bad pages can't take every run's budget. details_checked_at stays null:
-- the listing still has no details (thin_description needs them).
alter table public.listings add column details_failed_at timestamptz;

create or replace function public.mark_details_failed(p_source text, p_ids text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set details_failed_at = now()
  where source = p_source
    and source_listing_id = any (p_ids)
    and details_checked_at is null;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.mark_details_failed(text, text[])
  from public, anon, authenticated;

select public.recalculate_deal_scores();
