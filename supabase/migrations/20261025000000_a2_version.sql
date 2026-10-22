-- A2 versions become a risk signal (15.22; Rafael: a bike with its full
-- power from the factory is better than an A2 one, unlocked or not).
-- The 35 kW versions of the MT-07, R7, CB650R and CBR650R are the same bike
-- held back by a kit, sold to riders on their first licence:
--   a2_limited (15): still held back; the full power needs the kit taken
--     off and the registration papers changed, at the buyer's cost.
--   a2_unlocked (10): was held back and no longer is; the papers must show
--     the full power (insurance), and it was a new rider's bike.
-- Read from the ad's variant and description (power_version). Ads that only
-- say the bike can be held back ("pode ser limitada a 35 kW", "kit A2
-- incluído") are full-power bikes and count nothing. A new parameter
-- changes the signature, so the function and the view that calls it are
-- dropped and created again.

create function public.power_version(p_variant text, p_description text)
returns text
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 lower(concat_ws(' ', p_variant, p_description)),
                 -- Something that could be done, not what was done:
                 -- "pode ser limitada a 35 kW", "fácil de deslimitar",
                 -- "ideal para limitar", "kit A2 incluído".
                 '(pode(ndo)?\s+(ser|ficar|se)|possibilidade\s+de(\s+ser)?'
                 '|f[áa]cil(mente)?(\s+de)?|op[çc][ãa]o\s+de|preparad[ao]\s+para(\s+ser)?'
                 '|\mpara)\s+(\w+\s+){0,2}?(des)?(limit|bloque|restring)\w*'
                 '(\s+(a|para|em|aos?)\s+(35\s*kw|a2|\d+\s*(cv|hp)))?',
                 ' ', 'g'),
               '(des)?limit[áa]vel(\s+(a|para|em|aos?)\s+(35\s*kw|a2|\d+\s*(cv|hp)))?'
               '|kit\s+(de\s+)?(limita[çc][ãa]o|a2)\s+(inclu[íi]d[ao]|oferta|em\s+oferta|dispon[íi]vel|opcional)',
               ' ', 'g'),
             -- "não está limitada": said of a full-power bike.
             'n[ãa]o\s+(est[áa]\s+|[ée]\s+|vem\s+)?limitad[ao]',
             ' ', 'g') as d
  )
  select case
    when d ~ '(deslimit|desbloque|desrestring)\w*'
      or d ~ '(limita[çc][ãa]o|kit(\s+a2)?|restri[çc][ãa]o)\s+(foi\s+|j[áa]\s+)?(removid|retirad|tirad)'
      or d ~ '(estava|esteve|era|vinha)\s+(\w+\s+){0,2}?limitad'
      then 'a2_unlocked'
    when d ~ '(vers[ãa]o\s+full|full\s+power|pot[êe]ncia\s+(total|m[áa]xima|completa))'
      then null
    when d ~ 'limitad[ao]'
      or d ~ '\m35\s*kw'
      or d ~ 'vers[ãa]o\s+(a2|35)'
      or d ~ '\ma2\s+(limitad|kit|montad)'
      or d ~ 'kit\s+(de\s+)?(limita[çc][ãa]o|a2)\s+(montad|instalad|colocad)'
      then 'a2_limited'
  end
  from t
$$;

revoke all on function public.power_version(text, text) from public, anon, authenticated;

drop view public.listing_risk_scores;
drop function public.risk_assessment(
  numeric, numeric, integer, integer, text, text,
  boolean, boolean, integer, boolean, text, date, integer, timestamptz
);

-- As in 20261024110000_data_fixes.sql, plus the A2 signals (p_variant).
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
  p_on_sale_since  timestamptz default null,
  p_variant        text    default null
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
    -- An A2 (35 kW) version, still held back or unlocked (power_version).
    select v, case v when 'a2_limited' then 15 else 10 end
    from (select public.power_version(p_variant, p_description) as v) pv
    where v is not null
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
  l.details_checked_at is not null or l.source = 'olx',
  coalesce(l.seller_type::text = 'private', false),
  l.registrations,
  l.service_book,
  l.origin,
  l.warranty_until,
  (l.relisted_from is not null)::integer + (prev.relisted_from is not null)::integer,
  l.relisted_since,
  l.variant
) r
where l.status in ('active', 'price_changed');

select public.recalculate_deal_scores();
