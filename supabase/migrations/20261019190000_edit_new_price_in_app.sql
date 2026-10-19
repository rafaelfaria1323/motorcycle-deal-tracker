-- The new-bike list price is set from the app ("Modelos acompanhados")
-- instead of with SQL. Null clears it; the checked date is the day it was
-- confirmed on the brand's site (today by default).
create function public.set_model_new_price(
  p_motorcycle_id uuid,
  p_price         numeric,
  p_checked_at    date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();

  if p_price is not null and (p_price <= 0 or p_price > 200000) then
    raise exception 'Price % is out of range', p_price using errcode = '22023';
  end if;

  update public.motorcycles
  set new_price_reference  = p_price,
      new_price_checked_at = case when p_price is null then null
                                  else coalesce(p_checked_at, current_date) end,
      updated_at           = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.set_model_new_price(uuid, numeric, date)
  from public, anon;
grant execute on function public.set_model_new_price(uuid, numeric, date)
  to authenticated;
