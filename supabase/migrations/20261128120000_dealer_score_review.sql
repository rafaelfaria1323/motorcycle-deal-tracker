-- Dealer and risk scores revisited, and two cheaper reads (N.134).
--
-- 1. Sharp price changes (a step of half or more up or down) count only
--    between real prices: a placeholder ("1 €", "consultar": under 300 €,
--    minRealPrice) going to the real price was counted as a sharp change,
--    against the dealer and in "Qualidade dos dados". Each step is
--    compared with the previous real price, as the price history does
--    (N.128). A drop (`dropped`) counts only at a real price.
-- 2. The dealer view read and sorted the whole price history for every
--    query, also the dealer card's, which asks for one dealer: each ad now
--    reads only its own steps (index listing_price_history_listing_observed_idx).
-- 3. The seller slice (`dealer_score`): relists count half, as missing
--    mileage does (a dealer putting an unsold bike up again is routine
--    stock work, not a warning like a bait price or a repeated ad), and
--    a dealer's record is shrunk towards every scored dealer's rate with
--    the weight of 5 bikes (empirical Bayes): 1 relist among 5 bikes is
--    weak evidence, the same share among 50 is strong. Still only from 5
--    bikes.
-- 4. Risk: `mileage_lowered` no longer counts when the higher figure was
--    impossible (over 25 000 km a year for the bike's age, the rule of
--    `suspicious_mileage`): that edit corrects a typo, it doesn't hide km.
-- 5. `store_site_models`: the sites' brand and model lists in one call,
--    writing only rows that are new, renamed or a day old (the counts of
--    ads are refreshed daily), instead of rewriting every row each run.

-- 3. The seller slice.
drop function public.dealer_score(bigint, bigint, bigint, bigint, bigint, integer);

create function public.dealer_problems(
  p_relisted bigint, p_sharp_changes bigint, p_missing_mileage bigint,
  p_repeated bigint
) returns numeric
language sql immutable
set search_path = ''
as $$
  select coalesce(p_sharp_changes, 0)
         + coalesce(p_repeated, 0)
         + 0.5 * coalesce(p_relisted, 0)
         + 0.5 * coalesce(p_missing_mileage, 0)
$$;

-- p_prior_rate: the problems per bike of every dealer with enough bikes;
-- null scores the dealer's own record alone.
create function public.dealer_score(
  p_bikes bigint, p_problems numeric, p_prior_rate numeric default null,
  p_min_bikes integer default 5
) returns smallint
language sql immutable
set search_path = ''
as $$
  select case
    when coalesce(p_bikes, 0) >= p_min_bikes then
      greatest(0, least(100, round(100 - 100.0
        * (coalesce(p_problems, 0) + 5 * coalesce(p_prior_rate, 0))
        / (p_bikes + case when p_prior_rate is null then 0 else 5 end)
      )))::smallint
  end
$$;

revoke all on function public.dealer_problems(bigint, bigint, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.dealer_problems(bigint, bigint, bigint, bigint)
  to service_role;
revoke all on function public.dealer_score(bigint, numeric, numeric, integer)
  from public, anon, authenticated;
grant execute on function public.dealer_score(bigint, numeric, numeric, integer)
  to service_role;

-- 1 and 2. The dealer figures.
create or replace view public.dealer_reliability
with (security_invoker = true) as
with dealer_ads as (
  select l.id, l.source, l.seller_name, l.status, l.duplicate_of,
         l.relisted_from, l.mileage, l.price, l.initial_price,
         l.price_before_drop, l.first_seen_at,
         lower(btrim(l.seller_name)) as dealer_key,
         l.duplicate_of is null and exists (
           select 1
           from (
             select h.price,
                    lag(h.price) over (order by h.observed_at, h.id)
                      as previous_price
             from public.listing_price_history h
             where h.listing_id = l.id
               and h.price >= 300
           ) s
           where s.price >= s.previous_price * 1.5
              or s.price <= s.previous_price * 0.5
         ) as sharp
  from public.listings l
  where l.seller_type = 'dealer'
    and nullif(btrim(l.seller_name), '') is not null
)
select
  d.dealer_key,
  mode() within group (order by btrim(d.seller_name))        as seller_name,
  count(*) filter (where d.duplicate_of is null)             as bikes,
  count(*) filter (where d.duplicate_of is null
                     and d.status in ('active', 'price_changed')) as live,
  count(*) filter (where d.duplicate_of is null
                     and d.relisted_from is not null)        as relisted,
  count(*) filter (where d.sharp)                            as sharp_changes,
  count(*) filter (where d.duplicate_of is null
                     and d.mileage is null)                  as missing_mileage,
  count(*) filter (where d.duplicate_of is not null
                     and d.mileage >= 1000
                     and o.source = d.source)                as repeated,
  count(*) filter (where d.duplicate_of is null
                     and d.price >= 300
                     and d.price < greatest(d.initial_price, d.price_before_drop)
                     )                                       as dropped,
  min(d.first_seen_at)                                       as first_seen_at
from dealer_ads d
left join public.listings o on o.id = d.duplicate_of
group by d.dealer_key;

-- 1. The same rule in "Qualidade dos dados" (live ads, steps of the last
--    30 days, against the previous real price whenever it was seen).
create or replace view public.source_data_quality
with (security_invoker = true) as
with steps as (
  select h.listing_id,
         h.observed_at,
         h.price,
         lag(h.price) over (partition by h.listing_id
                            order by h.observed_at, h.id) as previous_price
  from public.listing_price_history h
  where h.price >= 300
),
sharp as (
  select distinct s.listing_id
  from steps s
  where s.observed_at >= now() - interval '30 days'
    and (s.price >= s.previous_price * 1.5
         or s.price <= s.previous_price * 0.5)
)
select
  source,
  count(*) as live_count,
  count(*) filter (where motorcycle_id is null) as unmatched_count,
  count(*) filter (where duplicate_of is not null) as duplicate_count,
  count(*) filter (where motorcycle_id is not null and duplicate_of is null)
    as scored_count,
  count(*) filter (where motorcycle_id is not null and duplicate_of is null
                     and year is null) as missing_year,
  count(*) filter (where motorcycle_id is not null and duplicate_of is null
                     and mileage is null) as missing_mileage,
  count(*) filter (where motorcycle_id is not null and duplicate_of is null
                     and nullif(trim(location), '') is null) as missing_location,
  count(*) filter (where source = 'standvirtual' and motorcycle_id is not null
                     and duplicate_of is null and details_checked_at is null)
    as details_pending,
  max(last_seen_at) as last_seen_at,
  count(*) filter (where id in (select listing_id from sharp))
    as sharp_price_changes
from public.listings l
where status in ('active', 'price_changed')
group by source;

-- 4. A lowered mileage after an impossible one is a correction.
create or replace function public.fact_edit_signals(
  p_mileage integer, p_mileage_from_text boolean, p_mileage_max_seen integer,
  p_year integer, p_year_first_seen integer
) returns text[]
language sql stable
set search_path = ''
as $$
  select array_remove(array[
    case when p_mileage is not null and not coalesce(p_mileage_from_text, false)
              and p_mileage_max_seen - p_mileage >= 1000
              and not coalesce(
                p_mileage_max_seen::numeric
                  / greatest(1, public.decimal_year() - (p_year + 0.5))
                > 25000, false)
         then 'mileage_lowered' end,
    case when p_year > p_year_first_seen then 'year_raised' end
  ], null)
$$;

-- 5. The sites' brand and model lists.
create function public.store_site_models(p_source text, p_models jsonb)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.site_models as s
    (source, make_id, make_name, model_id, model_name, ads, seen_at)
  select distinct on (m.make_id, m.model_id)
         p_source, m.make_id, m.make_name, m.model_id, m.model_name, m.ads,
         now()
  from jsonb_to_recordset(coalesce(p_models, '[]'::jsonb))
         as m(make_id text, make_name text, model_id text, model_name text,
              ads integer)
  where m.make_id is not null and m.model_id is not null
    and m.make_name is not null and m.model_name is not null
  order by m.make_id, m.model_id
  on conflict (source, make_id, model_id) do update
  set make_name = excluded.make_name,
      model_name = excluded.model_name,
      ads = excluded.ads,
      seen_at = excluded.seen_at
  where (s.make_name, s.model_name) is distinct from
          (excluded.make_name, excluded.model_name)
     or s.seen_at < now() - interval '1 day';
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.store_site_models(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.store_site_models(text, jsonb) to service_role;

-- 3. The run scores each dealer against every scored dealer's rate.
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql security definer
set search_path = ''
set jit = off
as $function$
declare
  n integer;
begin
  perform public.refresh_new_prices_from_ads();

  with dealer_counts as materialized (
    select d.dealer_key, d.bikes,
           public.dealer_problems(d.relisted, d.sharp_changes,
                                  d.missing_mileage, d.repeated) as problems
    from public.dealer_reliability d
  ),
  dealers as (
    select c.dealer_key, c.bikes,
           public.dealer_score(c.bikes, c.problems, p.rate) as score
    from dealer_counts c
    cross join (
      select sum(problems) / nullif(sum(bikes), 0) as rate
      from dealer_counts
      where bikes >= 5
    ) p
  ),
  fair as materialized (
    select f.listing_id, f.comparable_count, f.fair_price
    from public.listing_fair_prices f
  ),
  scored as materialized (
    select
      l.id,
      l.price,
      f.fair_price as market_price,
      public.damage_allowance(rs.reasons) as allowance,
      -- Not yet legalised in Portugal (N.52): what that costs comes off.
      public.legalisation_cost(
        rs.reasons, coalesce(m.engine_cc_max, m.engine_cc_min),
        case when l.price >= 300 then l.price else f.fair_price end,
        l.year, l.mileage) as legalisation,
      round((f.fair_price - l.price) / f.fair_price * 100, 1) as pct_below_market,
      f.comparable_count as listing_count,
      -- Nearly new (2 years or less from mid-year, at most half the normal
      -- mileage): also compared with the price of a new one (N.51).
      case when l.year is not null
            and public.decimal_year() - (l.year + 0.5) <= 2
            and public.mileage_use_score(l.mileage, l.year) = 100
           then coalesce(m.new_price_from_ads, m.new_price_reference)
      end as new_price,
      coalesce(public.mileage_use_score(l.mileage, l.year),
               -- Hidden mileage: no better than an average-to-high one.
               case when l.year is not null then 50 end) as m_score,
      public.age_score(l.year)        as y_score,
      rs.risk_score,
      rs.reasons,
      coalesce(l.text_extras,
               public.listing_extras(l.variant, l.description)) as extras,
      dl.score as seller_score,
      dl.bikes as dealer_bikes
    from public.listings l
    join public.motorcycles m on m.id = l.motorcycle_id
    left join fair f on f.listing_id = l.id
    left join lateral public.listing_risk(
      l, case when f.comparable_count >= 3 then f.fair_price end) rs on true
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
      s.allowance,
      -- least ignores nulls: the lower of the caps that apply.
      coalesce(least(c.deal_score,
                     public.damage_cap(s.reasons),
                     public.legalisation_cap(s.reasons)),
               c.deal_score) as deal_score,
      c.breakdown || jsonb_build_object(
        'market_price',         s.market_price,
        'pct_below_market',     s.pct_below_market,
        'market_listing_count', s.listing_count,
        'risk_reasons',         to_jsonb(coalesce(s.reasons, '{}'::text[])),
        'extras',               to_jsonb(s.extras),
        'valued_extras',        to_jsonb(public.valued_extras(s.extras)),
        'dealer_bikes',         s.dealer_bikes,
        'damage_allowance',     nullif(s.allowance, 0),
        'damaged_value',
          case when s.allowance > 0 then round(s.damaged_value) end,
        'pct_below_damaged_value',
          case when s.allowance > 0 and s.damaged_value > 0
               then round((s.damaged_value - s.price) / s.damaged_value * 100, 1)
          end,
        'new_price',            round(s.new_price),
        'pct_below_new',
          case when s.new_price > 0
               then round((s.new_price - s.price) / s.new_price * 100, 1)
          end,
        'legalisation_cost',
          case when s.legalisation > 0 then round(s.legalisation) end,
        'legalised_value',
          case when s.legalisation > 0 then round(s.compared_value) end,
        'pct_below_legalised_value',
          case when s.legalisation > 0 and s.compared_value > 0
               then round((s.compared_value - s.price) / s.compared_value * 100, 1)
          end,
        'capped_for_legalisation',
          coalesce(c.deal_score > public.legalisation_cap(s.reasons), false),
        'price_from_new',       coalesce(s.new_score > s.market_score
                                         or (s.market_score is null
                                             and s.new_score is not null), false),
        'capped_for_damage',
          coalesce(c.deal_score > public.damage_cap(s.reasons), false)
      ) as breakdown
    from (
      -- The price is scored against the value of the bike with its damage,
      -- so a damaged bike well below that still ranks high.
      -- A nearly new bike takes the better of that and its price against a
      -- new one's (not a damaged one: the damage is unseen; nor one still
      -- to be legalised).
      select s1.*,
             case when s1.new_score > s1.market_score
                    or s1.market_score is null
                  then coalesce(s1.new_score, s1.market_score)
                  else s1.market_score
             end as price_score
      from (
        select s0.*,
               s0.market_price * (1 - s0.allowance) as damaged_value,
               case when s0.listing_count >= 3
                    then public.price_score(s0.price,
                           greatest(s0.compared_value, 1), 2.5)
               end as market_score,
               case when s0.allowance = 0 and s0.legalisation = 0
                     and s0.new_price > 0
                    then public.price_score(s0.price, s0.new_price, 2.5)
               end as new_score
        from (
          -- The value the price is compared with: the estimate less a
          -- repair allowance and what legalising costs.
          select sc.*,
                 sc.market_price * (1 - sc.allowance) - sc.legalisation
                   as compared_value
          from scored sc
        ) s0
      ) s1
    ) s
    cross join lateral public.combine_deal_score(
      s.price_score, s.m_score, s.y_score, s.risk_score,
      cardinality(public.valued_extras(s.extras)), s.seller_score
    ) c
  )
  ,
  changed as (
    update public.listings l
    set deal_score      = c.deal_score,
        risk_score      = c.risk_score,
        score_breakdown = c.breakdown,
        scored_at       = now()
    from combined c
    where l.id = c.id
      and (l.deal_score, l.risk_score, l.score_breakdown, l.scored_at is null)
          is distinct from (c.deal_score, c.risk_score, c.breakdown, false)
    returning 1
  )
  select count(*) into n from combined;

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
$function$;
