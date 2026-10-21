-- Every import re-checks which catalog model the ads it read belong to:
-- `save` never updates a stored listing, so a match made by an older rule
-- (a Forza 125 taken for the Forza 350) stayed wrong for good.
--
-- p_matches: {source_listing_id: {"motorcycle_id": uuid or null, "brand",
-- "model"}} with the collector's current verdict. Only listings whose model
-- changes are touched (brand and model then follow, as on insert); returns
-- how many. Scores follow in recalculate_deal_scores at the end of the run.
create function public.rematch_listings(p_source text, p_matches jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set motorcycle_id = nullif(m.value ->> 'motorcycle_id', '')::uuid,
      brand         = m.value ->> 'brand',
      model         = m.value ->> 'model'
  from jsonb_each(p_matches) m
  where l.source = p_source
    and l.source_listing_id = m.key
    and l.motorcycle_id is distinct from
        nullif(m.value ->> 'motorcycle_id', '')::uuid;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.rematch_listings(text, jsonb)
  from public, anon, authenticated;
