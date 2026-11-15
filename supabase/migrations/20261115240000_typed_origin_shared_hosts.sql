-- B.6 (docs/bug-hunt.md 1.2, 4.2, 4.3).
--
-- (1) A typed ad can say the bike was imported ("Importada" in the app):
-- typed_ad_score takes p_origin ('imported') and passes it as a stored
-- ad's origin, so the "imported" sign counts (unless "not legalised"
-- replaces it, as for a stored ad).
--
-- (2) receive_shared_ad holds the account's limits against two shares at
-- once: a transaction lock on the account before the counts.
--
-- (3) Shared photos only from the hosts the sites serve them from
-- (Facebook's fbcdn.net, CustoJusto's own domain, OLX's olxcdn.com); the
-- reply says how many were left out.
drop function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer, text);

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
  p_to_year integer default null,
  p_variant text default null,
  p_origin text default null
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
         public.description_signals(nullif(btrim(coalesce(p_variant, '')), ''), p_description)
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
      -- The person says it was imported (B.6): the stored ads' sign.
      case when p_origin = 'imported' then 'imported' end,
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
      public.listing_extras(nullif(btrim(coalesce(p_variant, '')), ''), p_description) as extras
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
  integer, boolean, boolean, text, text, integer, integer, text, text) from public, anon, authenticated;
-- Only works out figures from what is already readable: open to visitors,
-- as bike_value is.
grant execute on function public.typed_ad_score(uuid, integer, integer, numeric, boolean,
  integer, boolean, boolean, text, text, integer, integer, text, text) to anon, authenticated;

-- A photo from a host the sites serve photos from.
create function public.shared_photo_host_allowed(p_url text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_url ~* '^https://([a-z0-9-]+\.)*(fbcdn\.net|custojusto\.pt|olxcdn\.com)(:443)?/', false)
$$;

revoke all on function public.shared_photo_host_allowed(text) from public, anon, authenticated;


create or replace function public.receive_shared_ad(p_key text, p_ad jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_user uuid;
  v_en boolean;
  v_url text;
  v_title text;
  v_version integer;
  v_lines text[];
  v_photos text[];
  v_left_out integer;
  v_text text;
  v_id uuid;
  v_message text;
begin
  -- The key from the body (a script with the key in it), else from the
  -- header x-deal-tracker-key (the shared shortcut: its script is the
  -- same for everyone, and the key is asked when it is installed).
  v_key := coalesce(
    nullif(btrim(p_key), ''),
    nullif(btrim(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-deal-tracker-key'), ''));
  select k.user_id into v_user from public.ad_import_keys k
  where k.key_hash = sha256(convert_to(coalesce(v_key, ''), 'UTF8'));
  if v_user is null then
    raise exception 'Chave desconhecida: crie uma nova no Deal Tracker (Mais › Atalho do iPhone). / Unknown key: make a new one in Deal Tracker (More › iPhone shortcut).'
      using errcode = '28000';
  end if;
  -- One share of the account at a time, so two at once can't both pass
  -- the limits below.
  perform pg_advisory_xact_lock(hashtextextended('shared_ads:' || v_user::text, 0));
  v_en := exists (select 1 from public.account_languages l
                  where l.user_id = v_user and l.language = 'en');

  v_url := btrim(case when jsonb_typeof(p_ad) = 'object'
                      and jsonb_typeof(p_ad -> 'url') = 'string'
                      then p_ad ->> 'url' end);
  if v_url is null or v_url !~ '^https://[^\s]+$' or length(v_url) > 2000 then
    raise exception '%', case when v_en
      then 'This page has no link to send. Share the ad from Safari.'
      else 'Esta página não tem um endereço para enviar. Partilhe o anúncio a partir do Safari.' end
      using errcode = '22023';
  end if;
  -- Without tracking (B.2), so the same ad sent again is the same address.
  v_url := public.shared_ad_url(v_url);

  -- Older than 7 days: gone, read or not (the day's count only needs one).
  delete from public.shared_ads s
  where s.user_id = v_user and s.received_at < now() - interval '7 days';

  if (select count(*) from public.shared_ads s
      where s.user_id = v_user and s.received_at > now() - interval '1 hour') >= 20
     or (select count(*) from public.shared_ads s
         where s.user_id = v_user and s.received_at > now() - interval '1 day') >= 100 then
    raise exception '%', case when v_en
      then 'Too many ads sent: wait a little and try again.'
      else 'Enviou anúncios demais: espere um pouco e tente de novo.' end
      using errcode = '54000';
  end if;
  -- The same ad sent again replaces the one waiting.
  delete from public.shared_ads s
  where s.user_id = v_user and s.url = v_url and s.dismissed_at is null;
  if (select count(*) from public.shared_ads s
      where s.user_id = v_user and s.dismissed_at is null) >= 10 then
    raise exception '%', case when v_en
      then '10 ads are already waiting: open "Check an ad" in Deal Tracker first.'
      else 'Já há 10 anúncios à espera: abra «Avaliar um anúncio» no Deal Tracker primeiro.' end
      using errcode = '54000';
  end if;

  v_title := nullif(left(btrim(public.without_phone_numbers(
    case when jsonb_typeof(p_ad -> 'title') = 'string' then p_ad ->> 'title' end)), 300), '');
  v_version := case when jsonb_typeof(p_ad -> 'version') = 'number'
                    then least(greatest((p_ad ->> 'version')::numeric, 0), 1000)::integer
                    else 0 end;
  select coalesce(array_agg(t.line order by t.n), '{}') into v_lines
  from (select left(btrim(public.without_phone_numbers(e.value)), 300) as line, e.n
        from jsonb_array_elements_text(
               case when jsonb_typeof(p_ad -> 'lines') = 'array' then p_ad -> 'lines'
                    else '[]' end) with ordinality as e (value, n)
        where e.n <= 60) t
  where t.line <> '';
  -- Each address once, in the page's order, the first 12, only from the
  -- hosts the sites serve photos from (B.6).
  with sent as (
    select distinct btrim(e.value #>> '{}') as photo
    from jsonb_array_elements(
           case when jsonb_typeof(p_ad -> 'photos') = 'array' then p_ad -> 'photos'
                else '[]' end) e
    where jsonb_typeof(e.value) = 'string'
  )
  select count(*) filter (where s.photo ~ '^https://[^\s]+$'
                            and not public.shared_photo_host_allowed(s.photo))::integer
  into v_left_out
  from sent s;
  v_photos := array(
    select d.photo from (
      select distinct on (x.photo) x.photo, x.n
      from (select btrim(e.value #>> '{}') as photo, e.n
            from jsonb_array_elements(
                   case when jsonb_typeof(p_ad -> 'photos') = 'array' then p_ad -> 'photos'
                        else '[]' end) with ordinality as e (value, n)
            where jsonb_typeof(e.value) = 'string') x
      where x.photo ~ '^https://[^\s]+$' and length(x.photo) <= 2000
        and public.shared_photo_host_allowed(x.photo)
      order by x.photo, x.n) d
    order by d.n
    limit 12);

  -- The page's own text (script 3): its lines up to the seller's part,
  -- without the lines about the seller, read by the app's rules.
  v_text := nullif(left(btrim(public.without_phone_numbers(
    case when jsonb_typeof(p_ad -> 'text') = 'string' then p_ad ->> 'text' end)), 8000), '');

  insert into public.shared_ads
    (user_id, url, title, description, price, old_price, page_text, lines, photos,
     script_version)
  values (
    v_user, v_url, v_title,
    nullif(left(btrim(public.without_phone_numbers(
      case when jsonb_typeof(p_ad -> 'description') = 'string'
           then p_ad ->> 'description' end)), 5000), ''),
    nullif(left(btrim(case when jsonb_typeof(p_ad -> 'price') in ('string', 'number')
                           then p_ad ->> 'price' end), 40), ''),
    nullif(left(btrim(case when jsonb_typeof(p_ad -> 'old_price') in ('string', 'number')
                           then p_ad ->> 'old_price' end), 40), ''),
    v_text, v_lines, v_photos, v_version)
  returning id into v_id;

  v_message := case when v_en
    then format('Sent to Deal Tracker: %s (%s photos).',
                coalesce(v_title, 'ad'), cardinality(v_photos))
    else format('Enviado para o Deal Tracker: %s (%s fotos).',
                coalesce(v_title, 'anúncio'), cardinality(v_photos)) end;
  if v_left_out > 0 then
    v_message := v_message || case when v_en
      then format(' Photos from other sites left out: %s.', v_left_out)
      else format(' Fotos de outros sites deixadas de fora: %s.', v_left_out) end;
  end if;
  if v_version < public.shared_ad_script_version() then
    v_message := v_message || case when v_en
      then ' The shortcut has a new version: install it again from More › iPhone shortcut.'
      else ' O atalho tem uma versão nova: instale-o de novo em Mais › Atalho do iPhone.' end;
  end if;
  return jsonb_build_object(
    'message', v_message,
    'outdated', v_version < public.shared_ad_script_version(),
    'id', v_id);
end;
$$;

revoke all on function public.receive_shared_ad(text, jsonb) from public, anon, authenticated;
grant execute on function public.receive_shared_ad(text, jsonb) to anon, authenticated;
