-- Switching a model off drops it from its listings (they leave the scores
-- and the market figures at once). Switching it back on used to leave them
-- unmatched for good: the collector only inserts new listings and never
-- rematches stored ones. Now switching on gives the model back to its
-- listings: a matched listing is stored with the catalog's brand and model
-- names (the collector writes the catalog model, never the site's text), so
-- the same names identify them again. Old and removed listings come back
-- too, so the price history and the market figures keep their past.
create or replace function public.set_model_tracked(p_motorcycle_id uuid, p_tracked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  update public.motorcycles
  set is_active = p_tracked, updated_at = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;

  if p_tracked then
    update public.listings l
    set motorcycle_id = m.id
    from public.motorcycles m
    where m.id = p_motorcycle_id
      and l.motorcycle_id is null
      and lower(l.brand) = lower(m.brand)
      and lower(l.model) = lower(m.model);
  else
    update public.listings set motorcycle_id = null
    where motorcycle_id = p_motorcycle_id;
  end if;

  perform public.recalculate_deal_scores();
end;
$$;

-- Models already switched back on get their listings back now.
update public.listings l
set motorcycle_id = m.id
from public.motorcycles m
where m.is_active
  and l.motorcycle_id is null
  and lower(l.brand) = lower(m.brand)
  and lower(l.model) = lower(m.model);

select public.recalculate_deal_scores();
