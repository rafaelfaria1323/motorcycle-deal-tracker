-- Typical time on the market (model_market_behaviour.median_days_to_gone):
-- the Kaplan-Meier median of the gone ads and those still for sale, which
-- count as lasting at least their age.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, published_at,
                             first_seen_at, last_seen_at)
select 'olx', 'mb' || d, 'https://x/mb' || d, m.id, m.brand, m.model,
       2020, 20000, 6000,
       case when d < 100 then 'removed' else 'active' end::public.listing_status,
       now() - interval '200 days', now() - interval '200 days',
       case when d < 100 then now() - interval '200 days' + d * interval '1 day'
            else now() end
from public.motorcycles m, unnest(array[10, 20, 30, 300, 301]) d
where m.slug = 'yamaha-r7';

do $$
declare b record;
begin
  select * into b from public.model_market_behaviour
  where motorcycle_id = (select id from public.motorcycles where slug = 'yamaha-r7');
  assert b.gone_count = 3 and b.live_count = 2, 'three gone, two live';
  -- The gone ones alone: 20 days. With the two on sale for 200 days the
  -- curve reaches half at day 30.
  assert b.median_days_to_gone = 30,
    format('typical time with the live ads, got %s', b.median_days_to_gone);
end $$;

-- Fewer than half gone: no typical time yet.
update public.listings set status = 'active', last_seen_at = now()
where source_listing_id = 'mb30';

do $$
begin
  assert (select median_days_to_gone from public.model_market_behaviour
          where motorcycle_id = (select id from public.motorcycles where slug = 'yamaha-r7'))
         is null, 'never half: no typical time';
end $$;
