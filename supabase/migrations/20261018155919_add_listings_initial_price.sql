alter table public.listings add column initial_price numeric(10, 2);

-- Backfill from the oldest history row, falling back to the current price.
update public.listings l
set initial_price = coalesce(
  (select h.price
   from public.listing_price_history h
   where h.listing_id = l.id
   order by h.observed_at asc
   limit 1),
  l.price
);

-- New listings start with their first price.
create function public.set_initial_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.initial_price := coalesce(new.initial_price, new.price);
  return new;
end;
$$;

create trigger listings_set_initial_price
before insert on public.listings
for each row execute function public.set_initial_price();