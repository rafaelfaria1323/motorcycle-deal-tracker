-- Recalls per model (N.86) from the EU's Safety Gate: the Commission's
-- public weekly reports (ec.europa.eu/safety-gate-alerts, XML, no key;
-- reuse allowed with the source acknowledged, docs/sources.md). The
-- database reads them itself, as it reads the fuel prices: the list of
-- reports, then each report not read yet, newest first, a few a run, and
-- keeps the motorcycle recalls. The app shows a model's recalls in
-- "Mercado deste modelo", the ones that may apply to an ad in Avaliação,
-- and asks at the visit whether each was done. No AI: the model is found
-- by its name and aliases in the recall's words.

-- Every weekly report since 2010 (the list holds them from 2005); read_at
-- once its motorcycle recalls are stored. No API access.
create table public.safety_gate_reports (
  reference    text primary key,
  url          text not null
    check (url like 'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/detail/xml/%'),
  published_on date not null,
  read_at      timestamptz,
  recalls      smallint check (recalls >= 0)
);

create index safety_gate_reports_unread
  on public.safety_gate_reports (published_on desc)
  where read_at is null;

alter table public.safety_gate_reports enable row level security;
revoke all on public.safety_gate_reports from anon, authenticated;

-- When the list was last read (one row, no API access).
create table public.safety_gate_state (
  id           boolean primary key default true check (id),
  list_read_at timestamptz
);
insert into public.safety_gate_state default values;

alter table public.safety_gate_state enable row level security;
revoke all on public.safety_gate_state from anon, authenticated;

-- The motorcycle recalls, as Safety Gate wrote them (English, and the
-- Portuguese of the same report when it could be read). `match_keys`: the
-- words the model is looked for in (recall_match_keys). Readable by
-- everyone; written only by refresh_vehicle_recalls().
create table public.vehicle_recalls (
  case_number      text primary key,
  report           text not null references public.safety_gate_reports (reference),
  published_on     date not null,
  brand            text,
  product          text,
  name             text,
  model_type       text,
  production_dates text,
  from_year        smallint,
  to_year          smallint,
  recall_code      text,
  alert_url        text check (alert_url like 'https://ec.europa.eu/%'),
  danger_en        text,
  danger_pt        text,
  country_en       text,
  country_pt       text,
  match_keys       text[] not null default '{}'
);

create index vehicle_recalls_report on public.vehicle_recalls (report);

alter table public.vehicle_recalls enable row level security;

create policy "Vehicle recalls are readable by everyone"
  on public.vehicle_recalls
  for select
  to anon, authenticated
  using (true);

-- The words a recall may name a model with: its words in lower case, and
-- two or three neighbours joined ("MT-07" -> mt07, "CB 650 R" -> cb650r,
-- "YZF-R7" -> r7).
create function public.recall_match_keys(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  with words as (
    select w, n
    from unnest(regexp_split_to_array(lower(coalesce(p_text, '')), '[^[:alnum:]]+'))
           with ordinality as t(w, n)
    where w <> ''
  ), numbered as (
    select w, row_number() over (order by n) as i from words
  )
  select coalesce(array_agg(distinct k), '{}')
  from (
    select a.w as k from numbered a
    union all
    select a.w || b.w from numbered a join numbered b on b.i = a.i + 1
    union all
    select a.w || b.w || c.w
    from numbered a
    join numbered b on b.i = a.i + 1
    join numbered c on c.i = a.i + 2
  ) keys
$$;
revoke all on function public.recall_match_keys(text) from public, anon, authenticated;

-- A catalog name as a key: lower case, letters and digits only.
create function public.recall_model_key(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(lower(regexp_replace(coalesce(p_name, ''), '[^[:alnum:]]', '', 'g')), '')
$$;
-- Pure; model_recalls (security invoker) needs it for every caller.
revoke all on function public.recall_model_key(text) from public;
grant execute on function public.recall_model_key(text) to anon, authenticated;

-- The years of production a recall names (the first and the last 4-digit
-- year in "22.10.2025 - 22.10.2026", "made in 2014 and 2015"); null when
-- it names none.
create function public.recall_years(p_text text, out from_year smallint, out to_year smallint)
language sql
immutable
set search_path = ''
as $$
  select min(y)::smallint, max(y)::smallint
  from (
    select m[1]::integer as y
    from regexp_matches(coalesce(p_text, ''), '(?:^|[^0-9])((?:19[5-9]|20[0-9])[0-9])(?![0-9])', 'g') m
  ) years
$$;
revoke all on function public.recall_years(text) from public, anon, authenticated;

-- Safety Gate's free text: trimmed, empty as null, without the "null "
-- older reports start some fields with.
create function public.safety_gate_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(btrim(regexp_replace(coalesce(p_text, ''), '^\s*null\s+', ''), E' \t\r\n'), '')
$$;
revoke all on function public.safety_gate_text(text) from public, anon, authenticated;

-- Whether a recall is of this catalog model: the brand among the recall's
-- brand or words, and the model's name or an alias (or with Honda's ABS
-- "A") among its keys.
create function public.recall_is_of_model(
  p_recall public.vehicle_recalls,
  p_bike   public.motorcycles
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select position(lower(p_bike.brand) in lower(concat_ws(' ', p_recall.brand, p_recall.product, p_recall.name))) > 0
     and exists (
       select
       from unnest(array_prepend(p_bike.model, p_bike.aliases)) as n(name)
       cross join lateral (select public.recall_model_key(n.name) as k) key
       where length(key.k) >= 2
         and (key.k = any(p_recall.match_keys) or key.k || 'a' = any(p_recall.match_keys))
     )
$$;
-- Pure; model_recalls (security invoker) needs it for every caller.
revoke all on function public.recall_is_of_model(public.vehicle_recalls, public.motorcycles)
  from public;
grant execute on function public.recall_is_of_model(public.vehicle_recalls, public.motorcycles)
  to anon, authenticated;

-- One HTTP GET of a Safety Gate address; null when it failed (warned).
create function public.safety_gate_get(p_url text)
returns xml
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_response extensions.http_response;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '30000');
  v_response := extensions.http((
    'GET',
    p_url,
    array[extensions.http_header('Accept', 'application/xml'),
          extensions.http_header('User-Agent',
            'MotorcycleDealTracker/0.1 (personal project, low volume)')],
    null,
    null
  )::extensions.http_request);
  if v_response.status <> 200 then
    raise warning 'Safety Gate not read (%): HTTP %', p_url, v_response.status;
    return null;
  end if;
  return xmlparse(document v_response.content);
exception when others then
  raise warning 'Safety Gate not read (%): %', p_url, sqlerrm;
  return null;
end;
$$;
revoke all on function public.safety_gate_get(text) from public, anon, authenticated;

-- Reads the list of weekly reports (at most once in 20 h) and then the
-- reports not read yet, newest first, for at most p_budget, p_pause
-- seconds apart. Keeps each report's motorcycle recalls (category "Motor
-- vehicles", a motorcycle, motorbike, moped or scooter), with the
-- Portuguese report's text for those. A report that can't be read waits
-- for the next run, which stops this one. Returns the reports read.
create function public.refresh_vehicle_recalls(
  p_budget interval default interval '2 minutes',
  p_pause  double precision default 3
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_started  timestamptz := clock_timestamp();
  v_doc      xml;
  v_report   record;
  v_read     integer := 0;
  v_found    integer;
  v_requests integer := 0;
begin
  if (select list_read_at is null or list_read_at < now() - interval '20 hours'
      from public.safety_gate_state where id) then
    v_doc := public.safety_gate_get(
      'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/list/xml/en');
    v_requests := 1;
    if v_doc is not null then
      begin
        insert into public.safety_gate_reports (reference, url, published_on)
        select r.reference, r.url, to_date(r.published, 'DD/MM/YYYY')
        from xmltable('/Safety-Gate/weeklyReport' passing v_doc
               columns reference text path 'reference',
                       published text path 'publicationDate',
                       url       text path 'URL') r
        where r.reference is not null
          and r.url like 'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/detail/xml/%'
          and r.published ~ '^\d{2}/\d{2}/\d{4}$'
          and to_date(r.published, 'DD/MM/YYYY') >= date '2010-01-01'
        on conflict (reference) do nothing;
        update public.safety_gate_state set list_read_at = now() where id;
      exception when others then
        raise warning 'Safety Gate list not understood: %', sqlerrm;
      end;
    end if;
  end if;

  for v_report in
    select reference, url from public.safety_gate_reports
    where read_at is null
    order by published_on desc, reference desc
  loop
    exit when clock_timestamp() - v_started > p_budget;
    if v_requests > 0 then perform pg_sleep(p_pause); end if;
    v_requests := v_requests + 1;
    v_doc := public.safety_gate_get(v_report.url);
    exit when v_doc is null;

    begin
      insert into public.vehicle_recalls (
        case_number, report, published_on, brand, product, name, model_type,
        production_dates, from_year, to_year, recall_code, alert_url,
        danger_en, country_en, match_keys)
      select n.case_number, v_report.reference,
             coalesce(to_date(n.published, 'DD-MM-YYYY'), current_date),
             n.brand, n.product, n.name, n.model_type, n.production_dates,
             y.from_year, y.to_year, n.recall_code,
             case when n.alert_url like 'https://ec.europa.eu/%' then n.alert_url end,
             n.danger, n.country,
             public.recall_match_keys(concat_ws(' ', n.product, n.name))
      from xmltable('/Safety-Gate/notifications' passing v_doc
             columns case_number      text path 'caseNumber',
                     published        text path 'publicationDate',
                     category         text path 'category',
                     product_raw      text path 'product',
                     brand_raw        text path 'brand',
                     name_raw         text path 'name',
                     model_type_raw   text path 'type_numberOfModel',
                     production_raw   text path 'productionDates',
                     recall_code_raw  text path 'companyRecallCode',
                     alert_url_raw    text path 'reference',
                     danger_raw       text path 'danger',
                     country_raw      text path 'notifyingCountry') x
      cross join lateral (
        select x.case_number, x.published,
               public.safety_gate_text(x.product_raw) as product,
               public.safety_gate_text(x.brand_raw) as brand,
               public.safety_gate_text(x.name_raw) as name,
               public.safety_gate_text(x.model_type_raw) as model_type,
               public.safety_gate_text(x.production_raw) as production_dates,
               public.safety_gate_text(x.recall_code_raw) as recall_code,
               public.safety_gate_text(x.alert_url_raw) as alert_url,
               public.safety_gate_text(x.danger_raw) as danger,
               public.safety_gate_text(x.country_raw) as country
      ) n
      cross join lateral public.recall_years(n.production_dates) y
      where x.case_number is not null
        and x.category = 'Motor vehicles'
        and x.product_raw ~* 'motor ?cycle|motorbike|moped|scooter'
        and (x.published is null or x.published ~ '^\d{2}-\d{2}-\d{4}$')
      on conflict (case_number) do nothing;
      get diagnostics v_found = row_count;
    exception when others then
      raise warning 'Safety Gate report % not understood: %', v_report.reference, sqlerrm;
      exit;
    end;

    -- The same report in Portuguese (Safety Gate's translation), only
    -- for reports with motorcycle recalls; without it the English stays.
    if v_found > 0 then
      perform pg_sleep(p_pause);
      v_requests := v_requests + 1;
      v_doc := public.safety_gate_get(replace(v_report.url, 'language=en', 'language=pt'));
      if v_doc is not null then
        begin
          update public.vehicle_recalls r
          set danger_pt = public.safety_gate_text(x.danger),
              country_pt = public.safety_gate_text(x.country)
          from xmltable('/Safety-Gate/notifications' passing v_doc
                 columns case_number text path 'caseNumber',
                         danger      text path 'danger',
                         country     text path 'notifyingCountry') x
          where r.case_number = x.case_number
            and r.report = v_report.reference;
        exception when others then
          raise warning 'Safety Gate report % (pt) not understood: %', v_report.reference, sqlerrm;
        end;
      end if;
    end if;

    update public.safety_gate_reports
    set read_at = now(), recalls = v_found
    where reference = v_report.reference;
    v_read := v_read + 1;
  end loop;

  return v_read;
end;
$$;
revoke all on function public.refresh_vehicle_recalls(interval, double precision)
  from public, anon, authenticated;

-- A model's recalls, newest first, as the app shows them (security
-- invoker: the catalog and the recalls are readable by everyone); with p_year
-- only those whose years of production may include it (a year after the
-- last, for a bike made late and registered the next year; all when the
-- recall names no years).
create function public.model_recalls(p_motorcycle_id uuid, p_year integer default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'case_number', r.case_number,
           'published_on', r.published_on,
           'name', concat_ws(' ', nullif(r.product, 'Motorcycle'), r.name),
           'production_dates', r.production_dates,
           'from_year', r.from_year,
           'to_year', r.to_year,
           'recall_code', r.recall_code,
           'alert_url', r.alert_url,
           'danger_en', r.danger_en,
           'danger_pt', r.danger_pt,
           'country_en', r.country_en,
           'country_pt', r.country_pt)
         order by r.published_on desc, r.case_number), '[]'::jsonb)
  from public.motorcycles m
  join public.vehicle_recalls r on public.recall_is_of_model(r, m)
  where m.id = p_motorcycle_id
    and (p_year is null or r.from_year is null
         or p_year between r.from_year and r.to_year + 1)
$$;
revoke all on function public.model_recalls(uuid, integer) from public;
grant execute on function public.model_recalls(uuid, integer) to anon, authenticated;

-- The computed field `listings.recalls`: the recalls of the ad's model
-- that may apply to its year (select it explicitly, never part of `*`).
create function public.recalls(l public.listings)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select case when l.motorcycle_id is null then '[]'::jsonb
              else public.model_recalls(l.motorcycle_id, l.year) end
$$;
revoke all on function public.recalls(public.listings) from public;
grant execute on function public.recalls(public.listings) to anon, authenticated;

-- Every hour: a no-op once the reports are read (the list itself at most
-- once in 20 h); while catching up, two minutes of reading.
select cron.schedule(
  'refresh-vehicle-recalls',
  '13 * * * *',
  $job$ select public.refresh_vehicle_recalls() $job$
);
