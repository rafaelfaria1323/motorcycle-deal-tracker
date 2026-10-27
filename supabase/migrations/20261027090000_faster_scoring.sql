-- The scoring run hit the collector's statement timeout (about 8 s on the
-- service role, from Supabase's defaults) once the market grew: run 44
-- failed with "canceling statement due to statement timeout". Measured on
-- 1 544 live listings with long descriptions: 27 s before, about 4 s after.
--
-- 1. The description's signals are stored: accident, repair, scratches,
--    A2 version and single owner (`text_signals`) and the extras
--    (`text_extras`), worked out by a trigger when the variant or the
--    description changes, not by every scoring run (their regexes were
--    85 % of it). text_contradictions stays live: it also reads the ad's
--    fields and today's year. A function behind them that changes later
--    must refresh them: `update public.listings set text_signals = null
--    where ...` (the trigger fills them again). Null (rows not filled
--    yet) is worked out on the fly.
-- 2. JIT off in recalculate_deal_scores: the query's estimated cost is
--    above jit_above_cost, so each run compiled it first (about 3 s, more
--    than it saved). A function's own setting applies, as the plan is
--    made inside it.
-- 3. `scored` materialized: inlined, its extras were worked out three
--    times per listing, once per use.
-- 4. The collector's role (service_role, used by nothing else) gets 60 s,
--    as headroom. A function's own statement_timeout doesn't work (the
--    timer is already running); a role setting does, since the API applies
--    the impersonated role's settings.

-- The description's own signals (risk_assessment's codes), from text only.
create function public.description_signals(p_variant text, p_description text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_remove(array[
    case when public.mentions_accident(p_description) then 'possible_accident' end,
    case when public.needs_repair(p_description) then 'needs_repair' end,
    case when public.cosmetic_damage(p_description) then 'cosmetic_damage' end,
    public.power_version(p_variant, p_description),
    case when public.single_owner_in_text(p_variant, p_description)
      then 'single_owner_in_text' end
  ], null)
$$;

revoke all on function public.description_signals(text, text)
  from public, anon, authenticated;

alter table public.listings
  add column text_signals text[],
  add column text_extras  text[];

comment on column public.listings.text_signals is
  'description_signals(variant, description), kept by a trigger';
comment on column public.listings.text_extras is
  'listing_extras(variant, description), kept by a trigger';

-- Only when the text changed: imports write the description on every run.
-- A null (a refresh) is filled again.
create function public.fill_text_signals()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT'
     or new.text_signals is null or new.text_extras is null
     or new.variant is distinct from old.variant
     or new.description is distinct from old.description then
    new.text_signals := public.description_signals(new.variant, new.description);
    new.text_extras := public.listing_extras(new.variant, new.description);
  end if;
  return new;
end;
$$;

revoke all on function public.fill_text_signals()
  from public, anon, authenticated;

create trigger listings_text_signals
  before insert or update of variant, description, text_signals, text_extras
  on public.listings
  for each row execute function public.fill_text_signals();

-- The live listings now; the others when they change (null meanwhile).
update public.listings
set text_signals = null
where status in ('active', 'price_changed');

-- risk_assessment's rules, the description's signals given.
create function public.risk_from_signals(
  p_price          numeric,
  p_market_price   numeric,
  p_year           integer,
  p_mileage        integer,
  p_description    text,
  p_location       text,
  p_details_known  boolean,
  p_private_seller boolean,
  p_registrations  integer,
  p_service_book   boolean,
  p_origin         text,
  p_warranty_until date,
  p_relists        integer,
  p_on_sale_since  timestamptz,
  p_text_signals   text[]
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
    where 'possible_accident' = any(p_text_signals)
    union all
    select 'needs_repair', 20
    where 'needs_repair' = any(p_text_signals)
    union all
    select 'cosmetic_damage', 5
    where 'cosmetic_damage' = any(p_text_signals)
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
    -- An A2 (35 kW) version, still held back or unlocked (power_version).
    select v, case v when 'a2_limited' then 15 else 10 end
    from unnest(p_text_signals) v
    where v in ('a2_limited', 'a2_unlocked')
    union all
    -- The ad's field, or the text when the field is empty.
    select 'first_owner', -5
    where p_registrations = 1
       or (p_registrations is null
           and 'single_owner_in_text' = any(p_text_signals))
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

revoke all on function public.risk_from_signals(
  numeric, numeric, integer, integer, text, text, boolean, boolean,
  integer, boolean, text, date, integer, timestamptz, text[]
) from public, anon, authenticated;

-- Same signature and result as in 20261025030000_single_owner_in_text.sql.
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
  p_on_sale_since  timestamptz default null,
  p_variant        text    default null
)
returns table (risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  select * from public.risk_from_signals(
    p_price, p_market_price, p_year, p_mileage, p_description, p_location,
    p_details_known, p_private_seller, p_registrations, p_service_book,
    p_origin, p_warranty_until, p_relists, p_on_sale_since,
    public.description_signals(p_variant, p_description))
$$;

-- As in 20261025000000_a2_version.sql, with the stored signals.
create or replace view public.listing_risk_scores
with (security_invoker = true) as
select
  l.id as listing_id,
  r.risk_score,
  r.reasons
from public.listings l
left join public.listing_fair_prices f on f.listing_id = l.id
left join public.listings prev on prev.id = l.relisted_from
cross join lateral public.risk_from_signals(
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
  l.relisted_since,
  coalesce(l.text_signals, public.description_signals(l.variant, l.description))
) r
where l.status in ('active', 'price_changed');

-- As in 20261025020000_damage_in_text.sql, with JIT off, `scored`
-- materialized and the stored extras.
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
set jit = off
as $$
declare
  n integer;
begin
  with dealers as (
    select d.dealer_key, d.bikes,
           public.dealer_score(d.bikes, d.relisted, d.sharp_changes,
                               d.missing_mileage, d.repeated) as score
    from public.dealer_reliability d
  ),
  scored as materialized (
    select
      l.id,
      ps.price_score,
      ps.market_price,
      ps.pct_below_market,
      ps.listing_count,
      coalesce(public.mileage_use_score(l.mileage, l.year),
               -- Hidden mileage: no better than an average-to-high one.
               case when l.year is not null then 50 end) as m_score,
      public.year_score(l.year)       as y_score,
      rs.risk_score,
      rs.reasons,
      coalesce(l.text_extras,
               public.listing_extras(l.variant, l.description)) as extras,
      dl.score as seller_score,
      dl.bikes as dealer_bikes
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    left join dealers dl
      on l.seller_type = 'dealer'
     and dl.dealer_key = lower(btrim(l.seller_name))
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
  ),
  combined as (
    select
      s.id,
      s.risk_score,
      case
        when c.deal_score > public.damage_cap(s.reasons)
          then public.damage_cap(s.reasons)
        else c.deal_score
      end as deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras),
        'valued_extras',        to_jsonb(public.valued_extras(s.extras)),
        'dealer_bikes',         s.dealer_bikes,
        'capped_for_damage',
          coalesce(c.deal_score > public.damage_cap(s.reasons), false)
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      cardinality(public.valued_extras(s.extras)), s.seller_score
    ) c
  )
  update public.listings l
  set deal_score      = c.deal_score,
      risk_score      = c.risk_score,
      score_breakdown = c.breakdown,
      scored_at       = now()
  from combined c
  where l.id = c.id;

  get diagnostics n = row_count;

  update public.listings
  set deal_score = null, risk_score = null,
      score_breakdown = null, scored_at = null
  where (status not in ('active', 'price_changed')
         or duplicate_of is not null
         or motorcycle_id is null)
    and (deal_score is not null or risk_score is not null
         or score_breakdown is not null);

  return n;
end;
$$;

do $$
begin
  alter role service_role set statement_timeout = '60s';
exception when insufficient_privilege then
  -- Not ours to change here: the 8 s default stays, the faster function
  -- above is then the whole fix.
  raise notice 'service_role statement_timeout left as it was: %', sqlerrm;
end;
$$;

-- The API reads role settings when it loads its configuration.
notify pgrst, 'reload config';
