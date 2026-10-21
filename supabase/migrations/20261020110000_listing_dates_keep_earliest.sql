-- Standvirtual now gives dates from its search pages too (createdAt and
-- the bump date), next to the listing page's originalCreatedAt. They can
-- differ, and a run must not move a date back and forth: keep the earliest
-- publication date and the latest renewal seen. least/greatest skip nulls,
-- so a missing date never erases a known one.
create or replace function public.apply_listing_dates(p_source text, p_dates jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set published_at      = least(l.published_at,
                                (d.value ->> 'published_at')::timestamptz),
      site_refreshed_at = greatest(l.site_refreshed_at,
                                   (d.value ->> 'site_refreshed_at')::timestamptz)
  from jsonb_each(p_dates) d
  where l.source = p_source
    and l.source_listing_id = d.key
    and (l.published_at is distinct from
           least(l.published_at, (d.value ->> 'published_at')::timestamptz)
         or l.site_refreshed_at is distinct from
           greatest(l.site_refreshed_at,
                    (d.value ->> 'site_refreshed_at')::timestamptz));

  get diagnostics n = row_count;
  return n;
end;
$$;
