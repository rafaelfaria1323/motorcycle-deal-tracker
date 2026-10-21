-- Prices: the first price is recorded, a changed price adds a history row
-- and marks the listing, an unchanged price does nothing.
insert into public.listings (source, source_listing_id, url, brand, model, price)
values ('olx', 'p1', 'https://x/p1', 'Yamaha', 'MT-07', 8000);
-- now() is the same all through a transaction: date the first price earlier
-- so the history has an order.
update public.listing_price_history set observed_at = now() - interval '1 hour';

do $$
declare
  l public.listings;
begin
  select * into l from public.listings where source_listing_id = 'p1';
  assert l.initial_price = 8000, 'initial price recorded';
  assert (select count(*) from public.listing_price_history where listing_id = l.id) = 1,
    'first price in the history';

  assert public.apply_price_updates('olx', '{"p1": 7500, "unknown": 1}') = 1,
    'one listing changed';
  select * into l from public.listings where source_listing_id = 'p1';
  assert l.price = 7500 and l.status = 'price_changed', 'new price, status price_changed';
  assert l.initial_price = 8000, 'initial price kept';
  assert (select array_agg(price order by observed_at)
          from public.listing_price_history where listing_id = l.id) = array[8000, 7500]::numeric[],
    'history holds both prices';

  assert public.apply_price_updates('olx', '{"p1": 7500}') = 0, 'same price: no change';
  assert public.apply_price_updates('standvirtual', '{"p1": 1}') = 0, 'other site: no change';
end $$;
