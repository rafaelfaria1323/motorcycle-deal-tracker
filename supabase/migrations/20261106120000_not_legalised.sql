-- Bikes not yet legalised in Portugal (N.52): the ad says it still has to
-- be legalised ("por legalizar", "proceder à legalização") or names a
-- foreign registration ("matrícula inglesa", "matriculada em Espanha")
-- without saying it is legalised already. The text signal is
-- not_legalised, or not_legalised_outside_eu for a bike from outside the
-- EU (United Kingdom, Switzerland, Norway): customs duty and VAT on top.
--
-- Score: the price is compared with the estimate less what legalising
-- costs (legalisation_cost: ISV by engine size, the inspection,
-- registration and plates; outside the EU about 30 % of the price for
-- duty and VAT; a nearly new bike from the EU pays 23 % VAT here), the
-- score is at most 79 (legalisation_cap: the real cost is unknown), and
-- the price of a new one is not used. Risk: not_legalised 15,
-- not_legalised_outside_eu 20, either in place of `imported`.

create or replace function public.legalisation_status(p_variant text, p_description text)
returns text
language sql
immutable
set search_path = ''
as $$
  with t as (
    -- "não precisa de legalizar" says the opposite.
    select regexp_replace(lower(concat_ws(' ', p_variant, p_description)),
             '(\mn[ãa]o|\mnunca)\s+(precis|necessit)\w*\s+(\w+\s+){0,2}?legaliz\w*',
             ' ', 'g') as d
  ),
  found as (
    select d,
      -- Still to do.
      d ~ ('\mn[ãa]o\s+(est[áa]\s+|se\s+encontra\s+|foi\s+)?legalizad'
           '|\m(por|para|a)\s+legalizar\M'
           '|\mfalta(m|r)?\s+([^\s.!?;]+\s+){0,8}?legaliz'
           '|\mproceder\s+[àa]\s+legaliza'
           '|(precis|necessit|carece)\w*\s+(de\s+)?(ser\s+)?legaliz'
           '|\mlegaliza[çc][ãa]o\s+([^\s.!?;]+\s+){0,3}?'
           '(a\s+cargo|por\s+conta|por\s+fazer|pendente|n[ãa]o\s+inclu)')
        as pending,
      -- A foreign registration.
      d ~ ('\mmatr[íi]cula\s+(\w+\s+)?(inglesa|brit[âa]nica|espanhola|francesa'
           '|alem[ãa]|italiana|holandesa|belga|su[íi][çc]a|luxemburguesa'
           '|estrangeira|do\s+reino\s+unido|\muk\M|\mgb\M)'
           '|\mmatriculad[ao]\s+(em|n[ao]s?)\s+(inglaterra|reino\s+unido|espanha'
           '|fran[çc]a|alemanha|it[áa]lia|holanda|b[ée]lgica|su[íi][çc]a'
           '|luxemburgo|estrangeiro|\muk\M)')
        as foreign_plate,
      -- Legalised already ("já legalizada", "matrícula portuguesa").
      regexp_replace(d, '\mn[ãa]o\s+(est[áa]\s+|se\s+encontra\s+|foi\s+)?legalizad\w*',
                     ' ', 'g')
        ~ ('\mlegalizad[ao]\M|\mmatr[íi]cula\s+(portuguesa|nacional)'
           '|\mmatr[íi]cula\s+pt\M')
        as done
    from t
  )
  select case
    when not (pending or (foreign_plate and not done)) then null
    when d ~ ('\m(matr[íi]cula|matriculad[ao]|importad[ao]|vind[ao]|veio|proveniente|origem)'
              '\s+([^\s.!?;]+\s+){0,3}?'
              '(ingl|brit[âa]n|reino\s+unido|\muk\M|\mgb\M|su[íi][çc]|noruega|esc[óo]c)')
      then 'not_legalised_outside_eu'
    else 'not_legalised'
  end
  from found
$$;

revoke all on function public.legalisation_status(text, text)
  from public, anon, authenticated;

-- ISV of a motorcycle (Tabela C by engine size, without the used-vehicle
-- reduction) = the app's isvBands. Check every January. Unknown size: the
-- top band.
create or replace function public.motorcycle_isv(p_engine_cc integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_engine_cc is null then 245.14
    when p_engine_cc <= 119 then 0
    when p_engine_cc <= 250 then 73.78
    when p_engine_cc <= 350 then 91.63
    when p_engine_cc <= 500 then 122.57
    when p_engine_cc <= 750 then 184.45
    else 245.14
  end
$$;

revoke all on function public.motorcycle_isv(integer)
  from public, anon, authenticated;

-- What legalising a bike costs (0 when the reasons hold no
-- not_legalised code): the ISV, the inspection (95 €), registration
-- (100 €) and plates (30 €), as the app's import calculator; from outside
-- the EU about 30 % of the price (6 % duty, then 23 % VAT on both); from
-- the EU, a bike of this year or the last with 6 000 km or less may be a
-- new means of transport and pay 23 % VAT here.
create or replace function public.legalisation_cost(
  p_reasons text[], p_engine_cc integer, p_price numeric,
  p_year integer, p_mileage integer
)
returns numeric
language sql
stable
set search_path = ''
as $$
  select case
    when not coalesce(p_reasons && array['not_legalised', 'not_legalised_outside_eu'], false)
      then 0
    else public.motorcycle_isv(p_engine_cc) + 95 + 100 + 30
      + coalesce(p_price, 0) * case
          when 'not_legalised_outside_eu' = any(p_reasons) then 0.30
          when p_year >= extract(year from current_date)::integer - 1
           and p_mileage <= 6000 then 0.23
          else 0
        end
  end
$$;

revoke all on function public.legalisation_cost(text[], integer, numeric, integer, integer)
  from public, anon, authenticated;

create or replace function public.legalisation_cap(p_reasons text[])
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case when p_reasons && array['not_legalised', 'not_legalised_outside_eu']
              then 79::smallint end
$$;

revoke all on function public.legalisation_cap(text[])
  from public, anon, authenticated;

create or replace function public.description_signals(p_variant text, p_description text)
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
      then 'single_owner_in_text' end,
    public.legalisation_status(p_variant, p_description)
  ], null)
$$;

revoke all on function public.description_signals(text, text)
  from public, anon, authenticated;

create or replace function public.risk_from_signals(p_price numeric, p_market_price numeric, p_year integer, p_mileage integer, p_description text, p_location text, p_details_known boolean, p_private_seller boolean, p_registrations integer, p_service_book boolean, p_origin text, p_warranty_until date, p_relists integer, p_on_sale_since timestamp with time zone, p_text_signals text[])
returns table(risk_score smallint, reasons text[])
language sql
stable
set search_path = ''
as $$
  -- Measured against the value of the bike with its damage
  -- (damage_allowance): a damaged bike priced like one isn't suspicious.
  with pct as (
    select case
      when p_price is null or p_market_price is null or p_market_price <= 0
        then null
      else (m.value - p_price) / m.value * 100
    end as below
    from (select p_market_price
                 * (1 - public.damage_allowance(p_text_signals)) as value) m
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
    select 'photos_reused', 10
    where 'photos_reused' = any(p_text_signals)
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
    -- Not yet legalised in Portugal (legalisation_status): more than
    -- imported, which it replaces.
    select v, case v when 'not_legalised_outside_eu' then 20 else 15 end
    from unnest(p_text_signals) v
    where v in ('not_legalised', 'not_legalised_outside_eu')
    union all
    select 'imported', 10 where p_origin is not null and p_origin <> 'national'
      and not coalesce(p_text_signals && array['not_legalised', 'not_legalised_outside_eu'], false)
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

revoke all on function public.risk_from_signals(numeric, numeric, integer, integer, text, text, boolean, boolean, integer, boolean, text, date, integer, timestamp with time zone, text[])
  from public, anon, authenticated;

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
      l.price,
      ps.market_price,
      public.damage_allowance(rs.reasons) as allowance,
      -- Not yet legalised in Portugal (N.52): what that costs comes off.
      public.legalisation_cost(
        rs.reasons, coalesce(m.engine_cc_max, m.engine_cc_min),
        case when l.price >= 300 then l.price else ps.market_price end,
        l.year, l.mileage) as legalisation,
      ps.pct_below_market,
      ps.listing_count,
      -- Nearly new (2 years or less from mid-year, at most half the normal
      -- mileage): also compared with the price of a new one (N.51).
      case when l.year is not null
            and public.decimal_year() - (l.year + 0.5) <= 2
            and public.mileage_use_score(l.mileage, l.year) = 100
           then m.new_price_reference
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

revoke all on function public.recalculate_deal_scores()
  from public, anon, authenticated;

-- The market position on the cards: against the value it is compared with.
create or replace function public.market_position(l public.listings)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when l.price >= 300
     and coalesce((l.score_breakdown ->> 'market_listing_count')::integer, 0) >= 3
    then round(
      case
        when l.score_breakdown ? 'legalisation_cost'
         and l.score_breakdown ? 'pct_below_legalised_value'
        then (l.score_breakdown ->> 'pct_below_legalised_value')::numeric
        when l.score_breakdown ? 'damage_allowance'
         and l.score_breakdown ? 'damaged_value'
        then (l.score_breakdown ->> 'pct_below_damaged_value')::numeric
        else (l.score_breakdown ->> 'pct_below_market')::numeric
      end, 1)
  end
$$;

-- The stored text signals of ads that may say so are worked out again
-- (the trigger fills them).
update public.listings
set text_signals = null
where concat_ws(' ', variant, description) ~* '(legaliz|matr[íi]cula|matriculad)';

select public.recalculate_deal_scores();
