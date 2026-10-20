-- "Chegou ao seu preço": a favourite's target price alerts its owner once
-- the listing is on sale at it or less, only for prices seen after the
-- target was set, once per target.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a7');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 7000
from public.motorcycles m, (values ('tp1'), ('tp2')) v(sid)
where m.slug = 'yamaha-mt-07';
-- now() is fixed in a transaction: the first prices come before the targets.
update public.listing_price_history set observed_at = now() - interval '3 hours';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a7';
set local test.jwt = '{"is_anonymous": false}';
insert into public.listing_favourites (listing_id)
select id from public.listings where source_listing_id in ('tp1', 'tp2');
-- The owner sets the targets through the API, like the app.
update public.listing_favourites set target_price = 6600;
reset role;

do $$
declare
  u constant uuid := '00000000-0000-0000-0000-0000000000a7';
  n int;
  refused boolean := false;
begin
  assert (select count(*) from public.listing_favourites
          where user_id = u and target_set_at = now()) = 2,
    'the database stamps when the target was set';
  begin
    update public.listing_favourites set target_price = 0 where user_id = u;
  exception when check_violation then refused := true;
  end;
  assert refused, 'a target of 0 is refused';

  -- Set an hour ago, so the prices below come after it.
  update public.listing_favourites set target_set_at = now() - interval '1 hour';

  assert public.generate_target_price_alerts() = 0, 'still above the target';

  -- tp1 drops to 6500 (below 6600); tp2 to 6700 (above).
  insert into public.listing_price_history (listing_id, price, observed_at)
  select id, case source_listing_id when 'tp1' then 6500 else 6700 end, now() - interval '10 minutes'
  from public.listings where source_listing_id in ('tp1', 'tp2');
  update public.listings set price = 6500 where source_listing_id = 'tp1';
  update public.listings set price = 6700 where source_listing_id = 'tp2';

  n := public.generate_alerts();
  assert (select count(*) from public.alerts a join public.listings l on l.id = a.listing_id
          where a.type = 'target_price_reached' and l.source_listing_id = 'tp1'
            and a.old_price = 6600 and a.new_price = 6500 and a.user_id = u) = 1,
    'tp1 reached the target';
  assert not exists (select 1 from public.alerts a join public.listings l on l.id = a.listing_id
                     where a.type = 'target_price_reached' and l.source_listing_id = 'tp2'),
    'tp2 did not';
  assert public.generate_target_price_alerts() = 0, 'once per target';

  -- A new target already above the price: nothing until a later price.
  update public.listing_favourites set target_price = 6900
  where listing_id = (select id from public.listings where source_listing_id = 'tp2');
  assert public.generate_target_price_alerts() = 0, 'only prices after the target count';

  -- A removed listing never alerts.
  update public.listing_favourites set target_set_at = now() - interval '1 hour';
  update public.listings set status = 'removed' where source_listing_id = 'tp2';
  assert public.generate_target_price_alerts() = 0, 'removed: no alert';
  update public.listings set status = 'active' where source_listing_id = 'tp2';
  assert public.generate_target_price_alerts() = 1, 'back on sale under the new target';

  -- Clearing the target clears its time.
  update public.listing_favourites set target_price = null where user_id = u;
  assert (select count(*) from public.listing_favourites where target_set_at is not null) = 0,
    'no target, no time';
end $$;
