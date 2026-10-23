-- A single owner said in the text counts as the ad's own field (Rafael,
-- 2026-10-23: sellers write "primeiro dono", "único dono"). When the ad
-- has no number of registrations, "primeiro dono", "único dono", "dono
-- único", "um só dono", "apenas 1 dono", "1º dono", "1ª mão" / "primeira
-- mão" or "first owner" / "one owner" in the variant (OLX's title) or the
-- description give the reassuring first_owner (-5), as registrations = 1
-- does. The field wins when it is there (2 or more: no bonus). Denials
-- don't count ("não é primeiro dono", "nunca foi único dono", "not the first owner").

create function public.single_owner_in_text(p_variant text, p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
           lower(concat_ws(' ', p_variant, p_description)),
           '(\mn[ãa]o\M|\mnunca\M|\mnot\M)\s+([^\s.,!?;]+\s+){0,3}?'
           '(primeir[oa]|[úu]nic[oa]|1\s*[ºªoa]|dono|first|one|single|only)\S*',
           ' ', 'g'
         ) ~ ('(primeiro|[úu]nico|1\s*[ºo])\s+(e\s+[úu]nico\s+)?(dono|propriet[áa]rio)'
              '|\m(dono|propriet[áa]rio)\s+[úu]nico'
              '|\m(apenas|s[óo]|somente)\s+(um|1)\s+(dono|propriet[áa]rio)'
              '|\m(um|1)\s+s[óo]\s+(dono|propriet[áa]rio)'
              '|\m1\s+(dono|propriet[áa]rio)\M'
              '|(primeira|1\s*[ªa])\s+m[ãa]o'
              '|\m(first|one|single|only)\s+owner')
$$;

revoke all on function public.single_owner_in_text(text, text) from public, anon, authenticated;

-- As in 20261025020000_damage_in_text.sql, with the text's single owner.
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
    select 'needs_repair', 20
    where public.needs_repair(p_description)
    union all
    select 'cosmetic_damage', 5
    where public.cosmetic_damage(p_description)
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
    -- The ad's field, or the text when the field is empty.
    select 'first_owner', -5
    where p_registrations = 1
       or (p_registrations is null
           and public.single_owner_in_text(p_variant, p_description))
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

select public.recalculate_deal_scores();
