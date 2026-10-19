-- When the site last renewed (bumped) an ad. OLX sorts and dates ads by it,
-- so it explains why OLX can show a newer date than the publication date.
alter table public.listings add column site_refreshed_at timestamptz;

-- Called by the collector after each import with the dates the site shows:
-- p_dates is {"<source_listing_id>": {"published_at": ..., "site_refreshed_at": ...}}.
-- Returns how many listings changed.
create function public.apply_listing_dates(p_source text, p_dates jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set published_at      = coalesce((d.value ->> 'published_at')::timestamptz,
                                   l.published_at),
      site_refreshed_at = coalesce((d.value ->> 'site_refreshed_at')::timestamptz,
                                   l.site_refreshed_at)
  from jsonb_each(p_dates) d
  where l.source = p_source
    and l.source_listing_id = d.key
    and (l.published_at is distinct from
           coalesce((d.value ->> 'published_at')::timestamptz, l.published_at)
         or l.site_refreshed_at is distinct from
           coalesce((d.value ->> 'site_refreshed_at')::timestamptz,
                    l.site_refreshed_at));

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_listing_dates(text, jsonb)
  from public, anon, authenticated;

-- Requests each site used in a run ({"standvirtual": 15, "olx": 9}), shown
-- in the app next to the per-run limit.
alter table public.collector_runs
  add column requests jsonb not null default '{}'::jsonb;
