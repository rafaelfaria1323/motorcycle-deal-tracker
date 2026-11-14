-- "Avaliar um anúncio" (N.102): an account pastes an OLX or Standvirtual
-- ad of a model it doesn't follow and gets the ad's Deal Score. One ad
-- alone gives no score: it needs the model's other ads. So the check is a
-- bike value request (16.9) with the ad's link: it collects the whole
-- model on both sites from the bike's year minus 3 for 30 days, and the
-- run that finds the ad scores it against the others; the collector then
-- pushes the score and a tap opens the ad. The ad itself comes in through
-- the model's searches (no single ad page is read, so the fetching rules
-- are unchanged); one the searches don't find is answered a day later as
-- not found, with the value of a bike of that year.

-- The site of an ad link ('olx' / 'standvirtual'), or null when it isn't
-- an ad of one of them: OLX `/d/anuncio/...-ID<code>.html` (also
-- `/d/pt/anuncio/`), Standvirtual `/motos/anuncio/...-ID<code>.html`.
create function public.ad_link_source(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_url ~* '^https?://(www\.|m\.)?olx\.pt/d/(pt/)?anuncio/[^?#]*-ID[0-9A-Za-z]+\.html'
      then 'olx'
    when p_url ~* '^https?://(www\.|m\.)?standvirtual\.com/motos/anuncio/[^?#]*-ID[0-9A-Za-z]+\.html'
      then 'standvirtual'
  end
$$;

-- The ad's code in its link ("ID8Q1m16"), the same in every address of
-- the ad (the words before it are the title's and may change).
create function public.ad_link_code(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when public.ad_link_source(p_url) is not null
    then substring(p_url from '-(ID[0-9A-Za-z]+)\.html')
  end
$$;

-- The stored listing of an ad link: the same site and code, the live one
-- first. Null when the collection hasn't stored it (or the link is no ad).
create function public.listing_for_ad(p_url text)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select l.id
  from public.listings l
  where l.source = public.ad_link_source(p_url)
    and substring(l.url from '-(ID[0-9A-Za-z]+)\.html') = public.ad_link_code(p_url)
  order by (l.status = 'active') desc, l.last_seen_at desc
  limit 1
$$;
revoke all on function public.listing_for_ad(text) from public;
grant execute on function public.listing_for_ad(text) to anon, authenticated, service_role;

alter table public.bike_value_requests
  add column ad_url text
  check (ad_url is null or public.ad_link_source(ad_url) is not null);

-- The listing of a request's ad (computed field `ad_listing`), null for a
-- plain valuation or an ad not stored.
create function public.ad_listing(r public.bike_value_requests)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select case when r.ad_url is not null then public.listing_for_ad(r.ad_url) end
$$;
revoke all on function public.ad_listing(public.bike_value_requests) from public;
grant execute on function public.ad_listing(public.bike_value_requests) to authenticated, service_role;

-- Asks for an ad's evaluation: [listing_id] at once when the ad is stored
-- and scored, else the request waits for the collection (the same cap as
-- valuations: 3 waiting a day). The model is the person's choice (the
-- link names no model reliably); it is collected from [p_year] minus 3.
create function public.request_ad_check(
  p_url text,
  p_motorcycle_id uuid,
  p_year integer,
  p_mileage integer default null
)
returns table (request_id uuid, listing_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text := btrim(p_url);
  v_listing uuid;
  v_id uuid;
begin
  perform public.require_account();

  if public.ad_link_source(v_url) is null then
    raise exception 'Not an OLX or Standvirtual ad link' using errcode = '22023';
  end if;
  -- Kept without the query and fragment (tracking, the site's own state).
  v_url := regexp_replace(v_url, '[?#].*$', '');
  if not exists (select 1 from public.motorcycles m where m.id = p_motorcycle_id) then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
  if p_year < 1990 or p_year > extract(year from now())::integer + 1 then
    raise exception 'Year % is out of range', p_year using errcode = '22023';
  end if;
  if p_mileage < 0 then
    raise exception 'Mileage % is invalid', p_mileage using errcode = '22023';
  end if;

  select l.id into v_listing
  from public.listings l
  where l.id = public.listing_for_ad(v_url)
    and l.scored_at is not null;

  if v_listing is null then
    select r.id into v_id
    from public.bike_value_requests r
    where r.user_id = auth.uid()
      and public.ad_link_source(r.ad_url) = public.ad_link_source(v_url)
      and public.ad_link_code(r.ad_url) = public.ad_link_code(v_url)
      and r.answered_at is null
    limit 1;
    if v_id is not null then
      return query select v_id, null::uuid;
      return;
    end if;

    if (select count(*) from public.bike_value_requests r
        where r.user_id = auth.uid() and r.waited
          and r.requested_at > now() - interval '1 day') >= 3 then
      raise exception 'At most 3 requests that wait for a collection a day'
        using errcode = '54000';
    end if;
  end if;

  insert into public.bike_value_requests
    (motorcycle_id, year, mileage, waited, answered_at, ad_url)
  values
    (p_motorcycle_id, p_year, p_mileage, v_listing is null,
     case when v_listing is not null then now() end, v_url)
  returning id into v_id;

  perform public.refresh_collected_model(p_motorcycle_id);

  return query select v_id, v_listing;
end;
$$;
revoke all on function public.request_ad_check(text, uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.request_ad_check(text, uuid, integer, integer)
  to authenticated, service_role;

-- The answers now say which are ad checks and the ad's scores. An ad
-- check is answered once this run saw its ad (scored before this step),
-- or a day on without it (not found: the value of a bike of that year).
-- A valuation as before: a run that read the model, or a day on.
drop function public.answer_bike_value_requests(timestamptz);
create function public.answer_bike_value_requests(p_started_at timestamptz)
returns table (
  id uuid,
  user_id uuid,
  brand text,
  model text,
  year integer,
  mileage integer,
  comparable_count integer,
  fair_price numeric,
  is_ad boolean,
  listing_id uuid,
  deal_score smallint,
  risk_score smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with answered as (
    update public.bike_value_requests r
    set answered_at = now()
    from public.motorcycles m
    where r.answered_at is null
      and m.id = r.motorcycle_id
      and m.is_active
      and m.collected_since <= p_started_at
      and m.min_year <= greatest(r.year - 3, 1990)
      and (r.requested_at < now() - interval '1 day'
           or (r.ad_url is null
               and exists (select 1 from public.listings l
                           where l.motorcycle_id = m.id
                             and l.last_seen_at >= p_started_at))
           or (r.ad_url is not null
               and exists (select 1 from public.listings l
                           where l.id = public.listing_for_ad(r.ad_url)
                             and l.last_seen_at >= p_started_at)))
    returning r.id, r.user_id, r.motorcycle_id, r.year, r.mileage, r.ad_url
  )
  select a.id, a.user_id, m.brand, m.model, a.year, a.mileage,
         v.comparable_count, v.fair_price,
         a.ad_url is not null, l.id, l.deal_score, l.risk_score
  from answered a
  join public.motorcycles m on m.id = a.motorcycle_id
  cross join lateral public.bike_value(a.motorcycle_id, a.year, a.mileage) v
  left join public.listings l
    on a.ad_url is not null and l.id = public.listing_for_ad(a.ad_url)
  order by a.id;
end;
$$;
revoke all on function public.answer_bike_value_requests(timestamptz)
  from public, anon, authenticated;
grant execute on function public.answer_bike_value_requests(timestamptz) to service_role;
