-- Recalls per model from Safety Gate (N.86): the list and the weekly
-- reports read through the http stub, the motorcycle recalls kept, matched
-- to the catalog by name and years, readable by everyone.

do $$
begin
  assert (select schedule from cron.job where jobname = 'refresh-vehicle-recalls') = '13 * * * *';

  -- Keys: words, and two or three neighbours joined.
  assert 'mt07' = any(public.recall_match_keys('Yamaha MT-07 (RM33)'));
  assert 'r7' = any(public.recall_match_keys('YZF-R7'));
  assert 'cb650r' = any(public.recall_match_keys('CB 650 R'));
  assert 'cbr650ra' = any(public.recall_match_keys('CBR650RA, CB650R'));
  assert public.recall_match_keys(null) = '{}';
  assert public.recall_model_key('MT-07') = 'mt07';
  assert public.recall_model_key(' - ') is null;

  -- Years of production.
  assert (public.recall_years('22.10.2025 - 22.10.2026')).from_year = 2025;
  assert (public.recall_years('22.10.2025 - 22.10.2026')).to_year = 2026;
  assert (public.recall_years('Vehicles manufactured in 2014 and 2015')).to_year = 2015;
  assert (public.recall_years('Serial numbers 120345 to 220500')).from_year is null;
  assert (public.recall_years('-')).from_year is null;

  assert public.safety_gate_text('null The fuel pump seal') = 'The fuel pump seal';
  assert public.safety_gate_text('  21D044' || E'\t\t') = '21D044';
  assert public.safety_gate_text('') is null;
end $$;

create temp table sg as select
  'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/list/xml/en'::text as list,
  'https://ec.europa.eu/safety-gate-alerts/api/download/weeklyReport/detail/xml/'::text as base;

-- One notification of a weekly report.
create function pg_temp.notification(p_case text, p_category text, p_product text,
                                     p_brand text, p_name text, p_dates text,
                                     p_danger text, p_country text)
returns text language sql as $$
  select '<notifications xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    || '<caseNumber>' || p_case || '</caseNumber>'
    || '<publicationDate>10-11-2026</publicationDate>'
    || '<reference><![CDATA[https://ec.europa.eu/safety-gate-alerts/screen/webReport/alertDetail/1]]></reference>'
    || '<category><![CDATA[' || p_category || ']]></category>'
    || '<product><![CDATA[' || p_product || ']]></product>'
    || '<brand><![CDATA[' || p_brand || ']]></brand>'
    || '<name><![CDATA[' || p_name || ']]></name>'
    || '<type_numberOfModel><![CDATA[e13*168/2013*00071]]></type_numberOfModel>'
    || '<danger><![CDATA[' || p_danger || ']]></danger>'
    || '<URLrecall/>'
    || '<notifyingCountry>' || p_country || '</notifyingCountry>'
    || '<companyRecallCode><![CDATA[3SJ]]></companyRecallCode>'
    || '<productionDates>' || p_dates || '</productionDates>'
    || '</notifications>'
$$;

do $$
declare
  v_sg   record;
  v_read integer;
  v_mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v_r7   uuid := (select id from public.motorcycles where slug = 'yamaha-r7');
  v_cb   uuid := (select id from public.motorcycles where slug = 'honda-cb650r');
  v_json jsonb;
begin
  select * into v_sg from sg;

  -- The list: three reports since 2010 (one with a damaged date), one
  -- from 2009 and one elsewhere.
  insert into extensions.http_replies (method, uri, status, content) values
  ('GET', v_sg.list, 200,
   '<?xml version="1.0" encoding="UTF-8"?><!-- About --><Safety-Gate>'
   || '<weeklyReport><reference>Report-2026-45</reference><publicationDate>13/11/2026</publicationDate>'
   || '<URL>' || v_sg.base || '45?language=en&amp;search=WEB_REPORT%7C:%7C45,</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-2026-44</reference><publicationDate>06/11/2026</publicationDate>'
   || '<URL>' || v_sg.base || '44?language=en&amp;search=WEB_REPORT%7C:%7C44,</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-2015-02</reference><publicationDate>16/01/2015</publicationDate>'
   || '<URL>' || v_sg.base || '15?language=en&amp;search=x</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-2015-01</reference><publicationDate>9 Jan 2015</publicationDate>'
   || '<URL>' || v_sg.base || '14?language=en</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-2009-50</reference><publicationDate>11/12/2009</publicationDate>'
   || '<URL>' || v_sg.base || '9?language=en</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-X</reference><publicationDate>11/12/2020</publicationDate>'
   || '<URL>https://example.com/x</URL></weeklyReport>'
   || '</Safety-Gate>');

  -- Week 45: an MT-07 and R7 recall, a car and a children's scooter
  -- (not motor vehicles), a Honda CRF; and its Portuguese.
  insert into extensions.http_replies (method, uri, status, content) values
  ('GET', v_sg.base || '45?language=en&search=WEB_REPORT%7C:%7C45,', 200,
   '<?xml version="1.0"?><Safety-Gate><report_week>45</report_week>'
   || pg_temp.notification('SR/1/26', 'Motor vehicles', 'Motorcycle', 'Yamaha',
        'MT-07, YZF-R7', '01.03.2024 - 30.06.2025', 'The rear brake may fail.', 'Germany')
   || pg_temp.notification('SR/2/26', 'Motor vehicles', 'Passenger car', 'Ford',
        'Ranger', '2025', 'Fire.', 'Germany')
   || pg_temp.notification('SR/3/26', 'Toys', 'Scooter', 'Yamaha', 'MT07 kids', '', 'Falls.', 'Spain')
   || pg_temp.notification('SR/4/26', 'Motor vehicles', 'Motorcycle', 'Honda',
        'CRF250R/RWE/RX, CRF450R/RWE/RX. ', '22.10.2025 - 22.10.2026', 'Handlebar.', 'Portugal')
   || '</Safety-Gate>'),
  ('GET', v_sg.base || '45?language=pt&search=WEB_REPORT%7C:%7C45,', 200,
   '<?xml version="1.0"?><Safety-Gate>'
   || pg_temp.notification('SR/1/26', 'Veículos motorizados', 'Motociclos', 'Yamaha',
        'MT-07, YZF-R7', '01.03.2024 - 30.06.2025', 'O travão traseiro pode falhar.', 'Alemanha')
   || '</Safety-Gate>'),
  -- Week 44: nothing for motorcycles.
  ('GET', v_sg.base || '44?language=en&search=WEB_REPORT%7C:%7C44,', 200,
   '<?xml version="1.0"?><Safety-Gate>'
   || pg_temp.notification('SR/5/26', 'Cosmetics', 'Cream', 'X', 'Y', '', 'Z.', 'France')
   || '</Safety-Gate>'),
  -- 2015, old style: the model in the product, no years.
  ('GET', v_sg.base || '15?language=en&search=x', 200,
   '<?xml version="1.0"?><Safety-Gate>'
   || pg_temp.notification('0158/15', 'Motor vehicles', 'Motorcycle/moped Honda CB 650 R', 'HONDA',
        '', '-', 'null The chain may break.', 'Spain')
   || '</Safety-Gate>');

  -- A budget of nothing: the list, then one report (the newest).
  v_read := public.refresh_vehicle_recalls(interval '0 seconds', 0);
  assert v_read = 0, v_read::text;
  assert (select count(*) from public.safety_gate_reports) = 3,
    (select string_agg(reference, ',') from public.safety_gate_reports);
  assert (select list_read_at from public.safety_gate_state) is not null;

  -- Then all of them: the list isn't read again within 20 h, the 2015
  -- report's Portuguese fails (no reply: '{}' isn't XML) and the English
  -- stays.
  delete from extensions.http_calls;
  v_read := public.refresh_vehicle_recalls(interval '1 minute', 0);
  assert v_read = 3, v_read::text;
  assert not exists (select from extensions.http_calls where uri = v_sg.list);
  -- Newest first; the Portuguese only for reports with recalls (the
  -- 2015 one's failed: its call is rolled back with the error).
  assert (select array_agg(uri order by ctid) from extensions.http_calls) = array[
    v_sg.base || '45?language=en&search=WEB_REPORT%7C:%7C45,',
    v_sg.base || '45?language=pt&search=WEB_REPORT%7C:%7C45,',
    v_sg.base || '44?language=en&search=WEB_REPORT%7C:%7C44,',
    v_sg.base || '15?language=en&search=x'],
    (select string_agg(uri, E'\n' order by ctid) from extensions.http_calls);

  assert (select array_agg(case_number order by case_number) from public.vehicle_recalls)
    = array['0158/15', 'SR/1/26', 'SR/4/26'];
  assert (select recalls from public.safety_gate_reports where reference = 'Report-2026-45') = 2;
  assert (select recalls from public.safety_gate_reports where reference = 'Report-2026-44') = 0;
  assert (select danger_pt from public.vehicle_recalls where case_number = 'SR/1/26')
    = 'O travão traseiro pode falhar.';
  assert (select country_pt from public.vehicle_recalls where case_number = 'SR/1/26') = 'Alemanha';
  assert (select danger_pt from public.vehicle_recalls where case_number = '0158/15') is null;
  assert (select danger_en from public.vehicle_recalls where case_number = '0158/15') = 'The chain may break.';
  assert (select from_year from public.vehicle_recalls where case_number = 'SR/1/26') = 2024;
  assert (select published_on from public.vehicle_recalls where case_number = 'SR/1/26') = date '2026-11-10';

  -- Nothing left: a run does nothing.
  delete from extensions.http_calls;
  assert public.refresh_vehicle_recalls(interval '1 minute', 0) = 0;
  assert (select count(*) from extensions.http_calls) = 0;

  -- Matching: MT-07 and R7 share the first; CB650R the old-style one.
  v_json := public.model_recalls(v_mt07);
  assert jsonb_array_length(v_json) = 1, v_json::text;
  assert v_json -> 0 ->> 'case_number' = 'SR/1/26';
  assert v_json -> 0 ->> 'name' = 'MT-07, YZF-R7', v_json::text;
  assert v_json -> 0 ->> 'recall_code' = '3SJ';
  assert jsonb_array_length(public.model_recalls(v_r7)) = 1;
  assert public.model_recalls(v_cb) -> 0 ->> 'case_number' = '0158/15';
  assert public.model_recalls(v_cb) -> 0 ->> 'name' = 'Motorcycle/moped Honda CB 650 R';
  -- The CRF is no catalog model; a CBR650R recall isn't the CB650R's.
  assert not exists (select from public.motorcycles m, public.vehicle_recalls r
                     where r.case_number = 'SR/4/26' and public.recall_is_of_model(r, m));
  assert jsonb_array_length(public.model_recalls(
    (select id from public.motorcycles where slug = 'honda-cbr650r'))) = 0;

  -- By year: made 2024-2025, so 2024 to 2026 may have it.
  assert jsonb_array_length(public.model_recalls(v_mt07, 2023)) = 0;
  assert jsonb_array_length(public.model_recalls(v_mt07, 2024)) = 1;
  assert jsonb_array_length(public.model_recalls(v_mt07, 2026)) = 1;
  assert jsonb_array_length(public.model_recalls(v_mt07, 2027)) = 0;
  -- No years named: every year.
  assert jsonb_array_length(public.model_recalls(v_cb, 2012)) = 1;
end $$;

-- A report that can't be read waits and stops the run.
do $$
declare
  v_sg record;
begin
  select * into v_sg from sg;
  update public.safety_gate_state set list_read_at = null where id;
  insert into extensions.http_replies (method, uri, status, content) values
  ('GET', v_sg.list, 200,
   '<?xml version="1.0"?><Safety-Gate>'
   || '<weeklyReport><reference>Report-2026-46</reference><publicationDate>20/11/2026</publicationDate>'
   || '<URL>' || v_sg.base || '46?language=en</URL></weeklyReport>'
   || '<weeklyReport><reference>Report-2010-01</reference><publicationDate>08/01/2010</publicationDate>'
   || '<URL>' || v_sg.base || '10?language=en</URL></weeklyReport></Safety-Gate>');
  delete from extensions.http_replies where uri = v_sg.list
    and content not like '%Report-2026-46%';
  insert into extensions.http_replies (method, uri, status, content)
  values ('GET', v_sg.base || '46?language=en', 503, 'busy');

  delete from extensions.http_calls;
  assert public.refresh_vehicle_recalls(interval '1 minute', 0) = 0;
  assert (select read_at from public.safety_gate_reports where reference = 'Report-2026-46') is null;
  assert (select read_at from public.safety_gate_reports where reference = 'Report-2010-01') is null;
  assert not exists (select from extensions.http_calls where uri like v_sg.base || '10%');

  -- The list unreadable: the unread reports are still read.
  update public.safety_gate_state set list_read_at = null where id;
  update extensions.http_replies set status = 500 where uri = v_sg.list;
  update extensions.http_replies set status = 200,
    content = '<?xml version="1.0"?><Safety-Gate></Safety-Gate>'
  where uri = v_sg.base || '46?language=en';
  assert public.refresh_vehicle_recalls(interval '1 minute', 0) = 1;
  assert (select list_read_at from public.safety_gate_state) is null;
end $$;

-- The computed field on a listing: its model's recalls for its year.
do $$
declare
  v_listing uuid;
begin
  insert into public.listings (source, source_listing_id, url, brand, model, motorcycle_id, year, price)
  values ('manual', 'recall-1', 'https://example.com/recall-1', 'Yamaha', 'MT-07',
          (select id from public.motorcycles where slug = 'yamaha-mt-07'), 2025, 6500)
  returning id into v_listing;
  assert (select jsonb_array_length(public.recalls(l)) from public.listings l where id = v_listing) = 1;
  update public.listings set year = 2020 where id = v_listing;
  assert (select jsonb_array_length(public.recalls(l)) from public.listings l where id = v_listing) = 0;
  update public.listings set motorcycle_id = null where id = v_listing;
  assert (select public.recalls(l) from public.listings l where id = v_listing) = '[]';
end $$;

-- Everyone reads the recalls; the reports and the reading are the
-- database's own.
set local role anon;
do $$
begin
  assert (select count(*) from public.vehicle_recalls) = 3;
  assert jsonb_array_length(public.model_recalls(
    (select id from public.motorcycles where slug = 'yamaha-mt-07'))) = 1;
  begin
    perform count(*) from public.safety_gate_reports;
    assert false, 'anon read the reports';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.vehicle_recalls (case_number, report, published_on)
    values ('x', 'Report-2026-45', current_date);
    assert false, 'anon wrote a recall';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.refresh_vehicle_recalls();
    assert false, 'anon read Safety Gate';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
