-- Every new listing starts its price history with the price it was first seen at.
create function public.record_initial_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.price is not null then
    insert into public.listing_price_history (listing_id, price, observed_at)
    values (new.id, new.price, coalesce(new.first_seen_at, now()));
  end if;
  return new;
end;
$$;

create trigger listings_record_initial_price
after insert on public.listings
for each row execute function public.record_initial_price();

-- Backfill: listings that have no history yet get their current price.
insert into public.listing_price_history (listing_id, price, observed_at)
select l.id, l.price, l.first_seen_at
from public.listings l
where l.price is not null
  and not exists (
    select 1 from public.listing_price_history h where h.listing_id = l.id
  );

-- Called by the collector after each import: these listings were seen just now.
create function public.mark_listings_seen(p_source text, p_ids text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set last_seen_at = now()
  where source = p_source
    and source_listing_id = any (p_ids);

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.mark_listings_seen(text, text[])
  from public, anon, authenticated;