-- Relisted ads become a risk signal (15.5): "relisted" (5 points) for a
-- bike put up again after its ad went, "relisted_often" (10) when that
-- happened twice or it has been on sale for over 90 days counting the
-- earlier ads (relisted_since). New parameters change the signature, so the
-- function and the view that calls it are dropped and created again.

drop view public.listing_risk_scores;
drop function public.risk_assessment(
  numeric, numeric, integer, integer, text, text,
  boolean, boolean, integer, boolean, text, date
);

-- Risk component (0-100, higher = riskier) plus the reasons that fired.
-- Negative points are reassuring facts; the total never goes below 0.
create function public.risk_assessment(
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
    -- Crude text match; phrases like "sem sinistros" are removed first.
    select 'possible_accident', 30
    where regexp_replace(
            lower(coalesce(p_description, '')),
            'sem\s+(sinistros?|acidentes?|danos?)', '', 'g'
          ) ~ '(sinistr|acident|batid[ao]|bateu)'
    union all
    select 'no_mileage', 15 where p_mileage is null
    union all
    select 'no_year', 10 where p_year is null
    union all
    -- A placeholder ("0", "1", "10") on a bike three or more years old, or
    -- far more than anyone rides in a year (bikes average 3-6 000 km).
    select 'suspicious_mileage', 10
    where p_mileage is not null and p_year is not null
      and (
        (p_mileage < 100
          and p_year <= extract(year from current_date)::integer - 3)
        or p_mileage::numeric
           / greatest(1, extract(year from current_date)::integer - p_year)
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

-- How many times the bike was relisted: this ad's previous one, and that
-- one's previous one (two is enough for the signal).
create view public.listing_risk_scores
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
  l.details_checked_at is not null,
  coalesce(l.seller_type::text = 'private', false),
  l.registrations,
  l.service_book,
  l.origin,
  l.warranty_until,
  (l.relisted_from is not null)::integer + (prev.relisted_from is not null)::integer,
  l.relisted_since
) r
where l.status in ('active', 'price_changed');

select public.recalculate_deal_scores();
