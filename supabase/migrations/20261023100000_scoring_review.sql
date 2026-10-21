-- Scoring review (Rafael, 2026-10-20: "revisit all of our calculations").
-- What changed and why:
--
-- 1. Equipment is a bonus, not a slice. As a slice (60 + 10 per extra, at
--    weight 15) one extra scored 70, so it LOWERED any listing whose other
--    slices were above 70 (90 -> 87 for a bike with a USB socket). Now +2
--    per extra, at most +10, added after the average.
-- 2. Without the price slice (fewer than 3 comparables) the score is at
--    most 70: a bike can't be called a very good deal without knowing how
--    its price compares (a new model with one other ad scored 98 and sent
--    an "excellent" alert).
-- 3. The price score reaches 0/100 at 20 % from the estimate (was 10 %),
--    so 11 % and 24 % below no longer score the same; and it needs 3
--    comparables, like the risk's price signal (was 2: one ad's price).
-- 4. Comparables within 3 years of the listing when there are at least 5
--    of them: the year adjustment is a rough rate, and a 2014 bike
--    compared mostly with 2019-2025 ones came out 39 % "below market".
--    The adjustment's clamp widens from x0.6-1.6 to x0.35-2.5.
-- 5. Ads under 300 € (parts, deposits, typos) are no comparables.
-- 6. Mileage is judged by the bike's age in days, not calendar years: the
--    normal mileage jumped by 5 000 km every 1 January (a 2024 bike with
--    10 000 km went from 58 to 85 overnight).
-- 7. No mileage given but the year known: the mileage part counts as 50,
--    so hiding the kilometres no longer scores better than a high figure.
-- 8. "Possible accident" no longer fires on "nunca teve acidentes", "sem
--    quedas nem acidentes", "livre de sinistros", "seguro contra todos os
--    riscos"... (mentions_accident).
-- 9. The text's year doesn't count when it is still to come or follows
--    "até" ("IUC pago até ao ano de 2027").
-- 10. slices_total said 6; there are 3 slices.

-- 6. The bike's age in years from mid-year registration, at least one.
drop function public.mileage_use_score(integer, integer, integer, integer);
drop function public.expected_mileage(integer, integer, integer);

-- Today as a decimal year (2026-07-02 is about 2026.5).
create function public.decimal_year(p_day date default current_date)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select extract(year from p_day)
         + (p_day - make_date(extract(year from p_day)::integer, 1, 1))
           / 365.25
$$;

create function public.expected_mileage(
  p_year           integer,
  p_km_per_year    integer default 5000,
  p_reference      numeric default public.decimal_year()
)
returns integer
language sql
stable
set search_path = ''
as $$
  select case when p_year is null then null
              else round(greatest(p_reference - (p_year + 0.5), 1) * p_km_per_year)::integer
         end
$$;

create function public.mileage_use_score(
  p_mileage        integer,
  p_year           integer,
  p_km_per_year    integer default 5000,
  p_reference      numeric default public.decimal_year()
)
returns smallint
language sql
stable
set search_path = ''
as $$
  select case
    when p_mileage is null or p_mileage < 0 then null
    when p_year is null then public.mileage_score(p_mileage)
    else (select greatest(0, least(100, round(case
                when r <= 0.5 then 100
                when r <= 1.5 then 100 - (r - 0.5) * 50
                else 50 - (r - 1.5) * 50
              end)))::smallint
          from (select p_mileage::numeric
                       / public.expected_mileage(p_year, p_km_per_year, p_reference) as r) x)
  end
$$;

revoke all on function public.decimal_year(date) from public, anon, authenticated;
revoke all on function public.expected_mileage(integer, integer, numeric)
  from public, anon, authenticated;
revoke all on function public.mileage_use_score(integer, integer, integer, numeric)
  from public, anon, authenticated;

-- 1, 2, 10. The deal score.
drop function public.combine_deal_score(
  integer, integer, integer, integer, integer,
  numeric, numeric, numeric, numeric, numeric
);
drop function public.equipment_score(text[]);

create function public.combine_deal_score(
  p_price_score     integer,
  p_mileage_score   integer,
  p_year_score      integer,
  p_risk_score      integer,
  p_extras          integer default 0,
  p_w_price         numeric default 35,
  p_w_year_mileage  numeric default 20,
  p_w_risk          numeric default 10,
  p_mileage_share   numeric default 0.7,
  p_points_per_extra integer default 2,
  p_max_extras      integer default 5,
  p_without_price   integer default 70
)
returns table (deal_score smallint, breakdown jsonb)
language sql
immutable
set search_path = ''
as $$
  with slices(name, weight, score) as (
    values
      ('price', p_w_price, p_price_score::numeric),
      ('year_mileage', p_w_year_mileage,
        case
          when p_mileage_score is not null and p_year_score is not null
            then p_mileage_share * p_mileage_score
               + (1 - p_mileage_share) * p_year_score
          else coalesce(p_mileage_score, p_year_score)::numeric
        end),
      ('risk', p_w_risk,
        case when p_risk_score is null then null else 100 - p_risk_score end::numeric)
  ),
  used as (select * from slices where score is not null),
  base as (
    select
      count(*) as n,
      case when count(*) > 0 then sum(weight * score) / sum(weight) end as score,
      bool_or(name = 'price') as has_price,
      coalesce(jsonb_object_agg(name, round(score, 1)), '{}'::jsonb) as scores,
      coalesce(jsonb_object_agg(name, weight), '{}'::jsonb) as weights
    from used
  ),
  bonus as (
    select p_points_per_extra * least(greatest(coalesce(p_extras, 0), 0), p_max_extras)
             as points
  )
  select
    case when b.n = 0 then null
         else round(least(
                case when b.has_price then 100 else p_without_price end,
                b.score + x.points))::smallint
    end,
    jsonb_build_object(
      'slices_used',     b.n,
      'slices_total',    3,
      'scores',          b.scores,
      'weights',         b.weights,
      'equipment_bonus', x.points,
      'capped_without_price',
        b.n > 0 and not coalesce(b.has_price, false)
        and b.score + x.points > p_without_price
    )
  from base b, bonus x
$$;

-- 4, 5. Comparables near the listing's year, no token prices.
create or replace function public.age_mileage_factor(
  p_year_diff   integer,
  p_km_diff     integer,
  p_per_year    numeric default 0.04,
  p_per_1000km  numeric default 0.002
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select greatest(0.35, least(2.5, exp(
    p_per_year * coalesce(p_year_diff, 0)
    - p_per_1000km * coalesce(p_km_diff, 0) / 1000.0
  )))
$$;

create or replace view public.listing_fair_prices
with (security_invoker = true) as
with live as (
  select l.*
  from public.listings l
  where l.motorcycle_id is not null
    and l.status in ('active', 'price_changed')
    and l.duplicate_of is null
    and l.price >= 300
),
pairs as (
  select l.id, l.year as l_year, l.mileage as l_mileage, l.motorcycle_id,
         c.id as c_id, c.year as c_year, c.mileage as c_mileage, c.price as c_price,
         abs(l.year - c.year) <= 3 as near
  from live l
  join live c
    on  c.motorcycle_id = l.motorcycle_id
    and c.id <> l.id
    -- A comparable without a year or mileage would count as the same age
    -- or mileage as the listing; leave it out when the listing has them.
    and (l.year is null or c.year is not null)
    and (l.mileage is null or c.mileage is not null)
),
chosen as (
  select p.*,
         -- Only the near ones when there are enough of them.
         count(*) filter (where p.near) over (partition by p.id) >= 5 as use_near
  from pairs p
)
select
  ch.id                as listing_id,
  count(ch.c_id)       as comparable_count,
  round((percentile_cont(0.5) within group (
    order by ch.c_price * public.age_mileage_factor(ch.l_year - ch.c_year,
                                                    ch.l_mileage - ch.c_mileage,
                                                    d.per_year,
                                                    d.per_1000km)
  ))::numeric, 2)      as fair_price
from chosen ch
join public.model_depreciation d on d.motorcycle_id = ch.motorcycle_id
where not ch.use_near or ch.near
group by ch.id;

-- 3. The price score over +-20 %, from 3 comparables.
create or replace view public.listing_price_scores
with (security_invoker = true) as
select
  l.id                                                          as listing_id,
  l.motorcycle_id,
  l.price,
  f.fair_price                                                  as market_price,
  f.comparable_count                                            as listing_count,
  round((f.fair_price - l.price) / f.fair_price * 100, 1)       as pct_below_market,
  case when f.comparable_count >= 3
       then public.price_score(l.price, f.fair_price, 2.5) end  as price_score,
  f.comparable_count >= 3                                       as is_reliable
from public.listings l
join public.listing_fair_prices f on f.listing_id = l.id
where l.status in ('active', 'price_changed')
  and l.duplicate_of is null
  and l.price is not null;

-- 8. Accident words, without the ways sellers say there was none (the
-- denial and the accident word within the same sentence, 3 words apart).
create function public.mentions_accident(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
           regexp_replace(
             lower(coalesce(p_description, '')),
             '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|livre\s+de|\mzero\M|isent[ao]\s+de)'
             '\s+([^\s.!?;]+\s+){0,3}?(sinistr\w*|acident\w*|danos?|batid[ao]s?|bateu|quedas?)',
             ' ', 'g'),
           -- Insurance wording: "seguro contra todos os riscos e sinistros".
           'seguro\s+.{0,40}sinistr\w*', ' ', 'g'
         ) ~ '(sinistr|acident|batid[ao]|bateu)'
$$;

revoke all on function public.mentions_accident(text) from public, anon, authenticated;

create or replace function public.text_contradictions(
  p_description  text,
  p_year         integer,
  p_mileage      integer,
  p_origin       text,
  p_service_book boolean
)
returns text[]
language sql
stable
set search_path = ''
as $$
  with t as (
    -- "IUC pago até ao ano de 2027" is no registration year.
    select regexp_replace(lower(coalesce(p_description, '')),
                          'at[ée]\s+(ao\s+|a\s+)?(ano|final)', ' ', 'g') as d
  ),
  found as (
    select
      (regexp_match(d,
        '(?:\mano|matr[ií]cula|matriculad[ao]|registo)\s*(?:de|em|:)?\s*((?:19|20)\d{2})\M'
      ))[1]::integer as text_year,
      regexp_match(d,
        '(?:\mtem|\mcom|apenas|\ms[oó]|\mkms?:?)\s+(\d{1,3}(?:[.\s]\d{3})+|\d+)\s*(mil)?\s*(?:km|kms|quil[oó]metros)\M'
      ) as km,
      regexp_replace(d,
        '(n[ãa]o|nunca)\s+(foi\s+|[ée]\s+)?importad[ao]', '', 'g'
      ) as d_no_negation,
      d
    from t
  ),
  values_found as (
    select
      text_year,
      case when km is not null then
        regexp_replace(km[1], '[.\s]', '', 'g')::numeric
        * case when km[2] is not null then 1000 else 1 end
      end as text_km,
      d_no_negation,
      d
    from found
  )
  select coalesce(array_agg(code order by code), '{}'::text[])
  from values_found,
  lateral (
    select 'text_year_mismatch' as code
    where text_year is not null and p_year is not null
      and abs(text_year - p_year) >= 2
      -- A year still to come is a date (inspection, insurance), not the bike's.
      and text_year <= extract(year from current_date)::integer
    union all
    select 'text_mileage_mismatch'
    where text_km is not null and p_mileage is not null
      and text_km > p_mileage * 1.2 and text_km - p_mileage >= 2000
    union all
    select 'text_origin_mismatch'
    where p_origin = 'national'
      and d_no_negation ~ '(importad[ao]|matr[ií]cula\s+(estrangeira|espanhola|francesa|alem[ãa]|italiana))'
    union all
    select 'text_service_book_mismatch'
    where p_service_book and d ~ '\msem\s+livro'
  ) codes
$$;


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


-- 7. The deal score with the changes above.
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with scored as (
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
      public.listing_extras(l.variant, l.description) as extras
    from public.listings l
    left join public.listing_price_scores ps on ps.listing_id = l.id
    left join public.listing_risk_scores  rs on rs.listing_id = l.id
    where l.status in ('active', 'price_changed')
      and l.duplicate_of is null
      and l.motorcycle_id is not null
  ),
  combined as (
    select
      s.id,
      s.risk_score,
      c.deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras)
      ) as breakdown
    from scored s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      cardinality(s.extras)
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

select public.recalculate_deal_scores();
