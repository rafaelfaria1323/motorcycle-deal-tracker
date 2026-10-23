-- Damage written in the description weighs more (15.24; Rafael, 2026-10-23:
-- a Honda ADV 350 scored "Excelente" while its ad said it "teve um toque
-- por trás" and needed the number plate holder; only reading the text
-- showed it).
--
-- 1. mentions_accident also reads falls and knocks: "caiu", "tombou", "foi
--    ao chão", "derrapou", "embate", "colisão", and "teve / sofreu / levou
--    um toque, uma pancada, uma queda". "Toque" and "queda" alone stay
--    silent ("macia ao toque", "queda de preço"), and "o preço caiu" too.
-- 2. needs_repair (20): repairs or parts the bike needs, or parts missing
--    or broken: "precisa do suporte de matrícula", "falta o pisca",
--    "espelho partido", "para peças", "avariada", "não pega", "amolgada".
--    Not "não precisa de nada", "para quem precisa", "precisa de carta A2",
--    "nada partido", "não falta nada".
-- 3. cosmetic_damage (5): scratches and dents on the surface ("riscos",
--    "arranhões", "mossas"); not "sem riscos" or "todos os riscos".
-- 4. A bike whose text tells of an accident or a repair still to do scores
--    at most 50 ("Fraco"): the estimated value is that of bikes without
--    damage, so a lower price is most likely the repair's cost, not a deal.
--    The breakdown says so (capped_for_damage). The risk score keeps every
--    signal as before.

-- A denial and the word it denies within the same sentence, 3 words apart,
-- as in 20261023100000_scoring_review.sql.
create or replace function public.mentions_accident(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 lower(coalesce(p_description, '')),
                 '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|\mnenhu\w*|livre\s+de|\mzero\M|isent[ao]\s+de)'
                 '\s+([^\s.,!?;]+\s+){0,3}?(sinistr\w*|acident\w*|danos?|batid[ao]s?|bateu'
                 '|quedas?|ca[ií]u|ca[ií]d[ao]s?|toques?|tomb\w*|embat\w*|colis\w*|colidiu'
                 '|pancadas?|derrap\w*|ao\s+ch[ãa]o)',
                 ' ', 'g'),
               -- Insurance wording: "seguro contra todos os riscos e sinistros".
               'seguro\s+.{0,40}sinistr\w*', ' ', 'g'),
             -- Prices fall too: "o preço caiu", "baixou".
             '(pre[çc]o|valor)\s+(\w+\s+){0,2}?ca[ií]u', ' ', 'g') as d
  )
  select d ~ '(sinistr|acident|batid[ao]|\mbateu\M|\mca[ií]u\M|\mca[ií]d[ao]\M|\mtomb(ou|ad[ao])\M'
             '|\membat|colis[ãa]o|colidiu|ao\s+ch[ãa]o|derrap)'
      or d ~ '\m(teve|sofreu|deu|levou|apanhou)\s+(um|uma)\s+(\w+\s+)?'
             '(toque|toquezinho|pancada|queda|tombo|batida|embate)'
  from t
$$;

-- The parts a seller names when one is missing or broken.
create function public.needs_repair(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with parts(p) as (
    select '(pisca|espelho|retrovisor|manete|carenage|farol|farolim|guarda-?lamas'
           '|suporte|ponteira|tampa|banco|pl[áa]stic|pe[çc]a|quadro|jante|para-?brisas?'
           '|bolha|pedal|poisa-?p[ée]s|sele[ct]?or|punho|escape|radiador|forquilha'
           '|guiador|dep[óo]sito|painel|matr[íi]cula|tanque|motor|embraiagem|caixa)'
  ),
  t as (
    select regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   lower(coalesce(p_description, '')),
                   -- An electric start is not a broken part.
                   '(bot[ãa]o|ponto|sistema)\s+de\s+partida'
                   '|partida\s+(el[ée]c?trica|a\s+frio|autom[áa]tica)',
                   ' ', 'g'),
                 -- "não precisa de nada", "sem nada partido", "não falta nada".
                 '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|\mnenhu\w*|\mnada\M|livre\s+de|\mzero\M'
                 '|isent[ao]\s+de)\s+([^\s.,!?;]+\s+){0,3}?'
                 '(precis\w*|necessit\w*|carece\w*|partid\w*|amolgad\w*|danific\w*|danos?'
                 '|avari\w*|falt\w*|empenad\w*|repara\w*)',
                 ' ', 'g'),
               -- "ideal para quem precisa de uma mota", "se precisar de".
               '\m(quem|se)\s+(\w+\s+)?(precis|necessit)\w*', ' ', 'g'),
             -- "precisa de carta A2", "necessita de licença".
             '(precis|necessit)\w*\s+(\w+\s+){0,2}?(carta|licen[çc]a|habilita[çc][ãa]o|categoria)',
             ' ', 'g') as d
  )
  select d ~ ('(precis|necessit|carece)\w*\s+([^\s.,!?;]+\s+){0,3}?'
              '(repar|arranj|substitu|pintur|bate-?chapa|' || p || ')')
      or d ~ '\mpara\s+(reparar|arranjar|recuperar|pe[çc]as)\M'
      or d ~ '\mavari'
      or d ~ '\mn[ãa]o\s+(pega|trabalha|arranca)\M'
      or d ~ '(amolgad|empenad|danificad)'
      or d ~ '\mdanos?\s+(n[oa]s?|em)\M'
      or d ~ ('\mfalta(m|r)?\s+([^\s.,!?;]+\s+){0,3}?\m' || p)
      or d ~ ('\m' || p || '\w*\s+([^\s.,!?;]+\s+){0,2}?em\s+falta')
      or d ~ ('\m' || p || '\w*\s+([^\s.,!?;]+\s+){0,3}?partid[ao]s?\M')
      or d ~ '\m(est[áa]|ficou|vem|veio)\s+(\w+\s+)?partid[ao]s?\M'
  from t, parts
$$;

revoke all on function public.needs_repair(text) from public, anon, authenticated;

create function public.cosmetic_damage(p_description text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
           regexp_replace(
             lower(coalesce(p_description, '')),
             '(\msem\M|\mnunca\M|\mn[ãa]o\M|\mnem\M|\mnenhu\w*|\mnada\M|livre\s+de|\mzero\M'
             '|isent[ao]\s+de)\s+([^\s.,!?;]+\s+){0,3}?(risc\w*|arranh\w*|mossas?|esfolad\w*)',
             ' ', 'g'),
           -- Insurance: "seguro contra todos os riscos".
           '(todos\s+os|contra|seguro\s+.{0,40})\s*riscos', ' ', 'g'
         ) ~ '(\mriscos?\M|riscad|arranh|\mmossas?\M|esfolad)'
$$;

revoke all on function public.cosmetic_damage(text) from public, anon, authenticated;

-- As in 20261025000000_a2_version.sql, plus needs_repair and cosmetic_damage.
-- The signature is the same, so the view keeps calling it.
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

-- The highest Deal Score a listing with these risk reasons can have: 50
-- when its text tells of an accident or a repair to do, else none.
create function public.damage_cap(p_reasons text[])
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_reasons && array['possible_accident', 'needs_repair'] then 50::smallint
  end
$$;

revoke all on function public.damage_cap(text[]) from public, anon, authenticated;

-- As in 20261024230000_extras_bonus.sql, with the damage cap.
create or replace function public.recalculate_deal_scores()
returns integer
language plpgsql
security definer
set search_path = ''
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
  scored as (
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
      public.listing_extras(l.variant, l.description) as extras,
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

select public.recalculate_deal_scores();
