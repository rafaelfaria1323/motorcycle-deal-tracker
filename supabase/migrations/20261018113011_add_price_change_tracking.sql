-- Whenever a listing's price changes: add a history row and flag the listing.
create function public.track_price_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.price is not null and new.price is distinct from old.price then
    insert into public.listing_price_history (listing_id, price, observed_at)
    values (new.id, new.price, now());

    if new.status = 'active' then
      new.status := 'price_changed';
    end if;
  end if;
  return new;
end;
$$;

create trigger listings_track_price_change
before update of price on public.listings
for each row execute function public.track_price_change();

-- Called by the collector: p_prices is {"<source_listing_id>": <price>, ...}.
-- Only listings whose price actually differs are updated; returns how many.
create function public.apply_price_updates(p_source text, p_prices jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings l
  set price = v.price
  from (
    select key as sid, value::numeric as price
    from jsonb_each_text(p_prices)
  ) v
  where l.source = p_source
    and l.source_listing_id = v.sid
    and l.price is distinct from v.price;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.apply_price_updates(text, jsonb)
  from public, anon, authenticated;