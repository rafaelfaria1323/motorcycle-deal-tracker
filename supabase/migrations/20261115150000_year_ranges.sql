-- N.108: year ranges.
--
-- (1) A last year for each followed model ("Modelos acompanhados"): an
-- account that wants, say, an MT-07 from 2018 to 2020 sees, is alerted
-- about and is summarised only those years. Collection does not change
-- (the sites are still searched from the earliest first year), so the
-- market figures keep every year's ads.
--
-- (2) A year range for the comparables of a bike's value and of a typed
-- ad's scores ("Quanto vale a minha mota", "Avaliar um anúncio"): with
-- one, the value is worked out from the stored ads of those years only
-- (still adjusted to the bike's year and mileage), instead of the tiers
-- bike_value picks itself (same generation, within 3 years, all).

alter table public.user_models
  add column max_year integer,
  add constraint user_models_max_year_check
    check (max_year is null or (max_year between 1990 and 2100 and max_year >= min_year));

create or replace function public.user_tracks(p_user uuid, p_motorcycle_id uuid, p_year integer)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.user_models u
                 where u.user_id = p_user
                   and u.motorcycle_id = p_motorcycle_id
                   and u.tracked
                   and (p_year is null or p_year >= u.min_year)
                   and (p_year is null or u.max_year is null or p_year <= u.max_year))
$$;

-- The account's own last year for a model; null: no last year.
create function public.my_max_year(m public.motorcycles)
returns integer
language sql
stable
set search_path = ''
as $$
  select u.max_year from public.user_models u
  where u.user_id = auth.uid() and u.motorcycle_id = m.id
$$;

grant execute on function public.my_max_year(public.motorcycles) to anon, authenticated;

-- The first and the last year (null: none) of a model for the caller.
create function public.set_model_years(
  p_motorcycle_id uuid,
  p_min_year integer,
  p_max_year integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last integer := extract(year from now())::integer + 1;
begin
  perform public.require_account();

  if p_min_year is null or p_min_year < 1990 or p_min_year > v_last then
    raise exception 'Year % is out of range', p_min_year using errcode = '22023';
  end if;
  if p_max_year is not null and (p_max_year < p_min_year or p_max_year > v_last) then
    raise exception 'Year % is out of range', p_max_year using errcode = '22023';
  end if;
  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  -- Years for a model not followed are kept for when it is.
  insert into public.user_models (user_id, motorcycle_id, tracked, min_year, max_year)
  values (auth.uid(), p_motorcycle_id, false, p_min_year, p_max_year)
  on conflict (user_id, motorcycle_id)
  do update set min_year = excluded.min_year,
                max_year = excluded.max_year,
                updated_at = now();

  perform public.refresh_collected_model(p_motorcycle_id);
end;
$$;

revoke all on function public.set_model_years(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.set_model_years(uuid, integer, integer) to authenticated;

-- A first year after the last one would break the check: the last year
-- moves with it.
create or replace function public.set_model_min_year(p_motorcycle_id uuid, p_min_year integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.set_model_years(
    p_motorcycle_id, p_min_year,
    (select case when u.max_year >= p_min_year then u.max_year end
     from public.user_models u
     where u.user_id = auth.uid() and u.motorcycle_id = p_motorcycle_id));
end;
$$;

-- bike_value with a year range for its comparables: null for both, the
-- tiers as before; with either, the live ads of those years only.
create function public.bike_value_in_years(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer,
  p_from_year integer,
  p_to_year integer
)
returns table(comparable_count integer, fair_price numeric, low_price numeric, high_price numeric)
language sql
stable
set search_path = ''
as $$
  with generations as (
    select m.generation_years as years
    from public.motorcycles m where m.id = p_motorcycle_id
  ),
  comparables as (
    select c.year, c.mileage, c.price,
           p_year is not null and abs(p_year - c.year) <= 3 as near,
           p_year is not null and abs(p_year - c.year) <= 3
             and public.model_generation(g.years, c.year)
                 = public.model_generation(g.years, p_year) as same_generation
    from public.listings c
    cross join generations g
    where c.motorcycle_id = p_motorcycle_id
      and c.status in ('active', 'price_changed')
      and c.duplicate_of is null
      and c.price >= 300
      and (p_year is null or c.year is not null)
      and (p_mileage is null or c.mileage is not null)
      and (p_from_year is null or c.year >= p_from_year)
      and (p_to_year is null or c.year <= p_to_year)
  ),
  chosen as (
    select c.*
    from comparables c
    where case
      when p_from_year is not null or p_to_year is not null then true
      when (select count(*) from comparables n where n.same_generation) >= 5
        then c.same_generation
      when (select count(*) from comparables n where n.near) >= 5 then c.near
      else true
    end
  ),
  adjusted as (
    select ch.price * public.age_mileage_factor(
             p_year - ch.year,
             p_mileage - ch.mileage,
             coalesce(d.per_year, 0.04),
             coalesce(d.per_1000km, 0.002)
           ) as price
    from chosen ch
    left join public.model_depreciation d on d.motorcycle_id = p_motorcycle_id
  )
  select
    count(*)::integer,
    round((percentile_cont(0.5)  within group (order by price))::numeric, 2),
    round((percentile_cont(0.25) within group (order by price))::numeric, 2),
    round((percentile_cont(0.75) within group (order by price))::numeric, 2)
  from adjusted;
$$;

grant execute on function public.bike_value_in_years(uuid, integer, integer, integer, integer)
  to anon, authenticated;

create or replace function public.bike_value(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null
)
returns table(comparable_count integer, fair_price numeric, low_price numeric, high_price numeric)
language sql
stable
set search_path = ''
as $$
  select * from public.bike_value_in_years(p_motorcycle_id, p_year, p_mileage, null, null);
$$;

-- typed_ad_score with the same year range for its comparables.
drop function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text);

create function public.typed_ad_score(
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer,
  p_price numeric,
  p_private_seller boolean,
  p_registrations integer default null,
  p_service_book boolean default null,
  p_warranty boolean default false,
  p_damage text default null,
  p_description text default null,
  p_from_year integer default null,
  p_to_year integer default null
)
returns table(deal_score smallint, risk_score smallint, breakdown jsonb)
language sql
stable
security definer
set search_path = ''
set jit = off
as $$
  with model as (
    select m.id, coalesce(m.engine_cc_max, m.engine_cc_min) as engine_cc,
           coalesce(m.new_price_from_ads, m.new_price_reference) as new_price
    from public.motorcycles m
    where m.id = p_motorcycle_id
  ),
  input as (
    select
      md.*,
      nullif(btrim(coalesce(p_description, '')), '') as description,
      v.comparable_count,
      v.fair_price,
      (select coalesce(array_agg(distinct s), '{}'::text[])
       from unnest(
         public.description_signals(null, p_description)
         || case p_damage
              when 'accident' then array['possible_accident']
              when 'dropped' then array['cosmetic_damage']
              else '{}'::text[]
            end) s) as signals
    from model md
    cross join lateral public.bike_value_in_years(md.id, p_year, p_mileage, p_from_year, p_to_year) v
  ),
  risk as (
    select i.*, r.risk_score, r.reasons
    from input i
    cross join lateral public.risk_from_signals(
      p_price,
      case when i.comparable_count >= 3 then i.fair_price end,
      p_year, p_mileage, i.description,
      -- The place isn't asked: no "no location" sign.
      'typed',
      -- A pasted description is the ad's whole text.
      i.description is not null,
      coalesce(p_private_seller, false),
      p_registrations, p_service_book,
      null,
      case when p_warranty then current_date + 1 end,
      0, null,
      i.signals) r
  ),
  scored as (
    select
      r.*,
      public.damage_allowance(r.reasons) as allowance,
      public.legalisation_cost(
        r.reasons, r.engine_cc,
        case when p_price >= 300 then p_price else r.fair_price end,
        p_year, p_mileage) as legalisation,
      case when p_year is not null
            and public.decimal_year() - (p_year + 0.5) <= 2
            and public.mileage_use_score(p_mileage, p_year) = 100
           then r.new_price
      end as near_new_price,
      coalesce(public.mileage_use_score(p_mileage, p_year),
               case when p_year is not null then 50 end) as m_score,
      public.age_score(p_year) as y_score,
      public.listing_extras(null, p_description) as extras
    from risk r
  ),
  priced as (
    select s1.*,
           case when s1.new_score > s1.market_score or s1.market_score is null
                then coalesce(s1.new_score, s1.market_score)
                else s1.market_score
           end as price_score
    from (
      select s0.*,
             case when s0.comparable_count >= 3 and s0.fair_price > 0
                  then public.price_score(p_price, greatest(s0.compared_value, 1), 2.5)
             end as market_score,
             case when s0.allowance = 0 and s0.legalisation = 0
                   and s0.near_new_price > 0
                  then public.price_score(p_price, s0.near_new_price, 2.5)
             end as new_score
      from (
        select s.*,
               s.fair_price * (1 - s.allowance) as damaged_value,
               s.fair_price * (1 - s.allowance) - s.legalisation as compared_value
        from scored s
      ) s0
    ) s1
  )
  select
    coalesce(least(c.deal_score,
                   public.damage_cap(p.reasons),
                   public.legalisation_cap(p.reasons)),
             c.deal_score),
    p.risk_score,
    c.breakdown || jsonb_build_object(
      'market_price',         p.fair_price,
      'pct_below_market',
        case when p.fair_price > 0
             then round((p.fair_price - p_price) / p.fair_price * 100, 1)
        end,
      'market_listing_count', p.comparable_count,
      'risk_reasons',         to_jsonb(coalesce(p.reasons, '{}'::text[])),
      'extras',               to_jsonb(p.extras),
      'valued_extras',        to_jsonb(public.valued_extras(p.extras)),
      'damage_allowance',     nullif(p.allowance, 0),
      'damaged_value',
        case when p.allowance > 0 then round(p.damaged_value) end,
      'pct_below_damaged_value',
        case when p.allowance > 0 and p.damaged_value > 0
             then round((p.damaged_value - p_price) / p.damaged_value * 100, 1)
        end,
      'new_price',            round(p.near_new_price),
      'pct_below_new',
        case when p.near_new_price > 0
             then round((p.near_new_price - p_price) / p.near_new_price * 100, 1)
        end,
      'legalisation_cost',
        case when p.legalisation > 0 then round(p.legalisation) end,
      'legalised_value',
        case when p.legalisation > 0 then round(p.compared_value) end,
      'pct_below_legalised_value',
        case when p.legalisation > 0 and p.compared_value > 0
             then round((p.compared_value - p_price) / p.compared_value * 100, 1)
        end,
      'capped_for_legalisation',
        coalesce(c.deal_score > public.legalisation_cap(p.reasons), false),
      'price_from_new',
        coalesce(p.new_score > p.market_score
                 or (p.market_score is null and p.new_score is not null), false),
      'capped_for_damage',
        coalesce(c.deal_score > public.damage_cap(p.reasons), false)
    )
  from priced p
  cross join lateral public.combine_deal_score(
    p.price_score, p.m_score, p.y_score, p.risk_score,
    cardinality(public.valued_extras(p.extras)), null
  ) c
  where p_price >= 300
$$;

revoke all on function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer) from public, anon, authenticated;
-- Only works out figures from what is already readable: open to visitors,
-- as bike_value is.
grant execute on function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer) to anon, authenticated;
