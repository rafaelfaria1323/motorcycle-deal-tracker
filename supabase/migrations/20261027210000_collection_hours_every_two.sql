-- Rafael, 2026-10-27: collections every 2 hours from 08:00 to 22:00, plus
-- 00:00 (Lisbon time), was 00:00, 08:00 and every 2 hours from 12:00 to
-- 20:00. The night gap (00:00 to 08:00) stays 8 hours, under the
-- watchdog's 9. collection_text.dart in the app mirrors these hours.
create or replace function public.collection_due(p_now timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select extract(hour from p_now at time zone 'Europe/Lisbon')::integer
         = any (array[0, 8, 10, 12, 14, 16, 18, 20, 22])
$$;
