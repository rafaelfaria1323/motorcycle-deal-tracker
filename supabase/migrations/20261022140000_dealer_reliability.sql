-- Dealer reliability (15.7), first step: the figures per dealer, shown on
-- the listing page; no score yet (that needs a few weeks of data per
-- dealer). Only dealers have a name stored (never private sellers), so
-- private sellers never appear here.
--
-- A dealer is its name, trimmed and case-folded, across both sites. Counted
-- over every ad we have seen of it (live and gone):
--   bikes             ads that are not a repeat of another ad (duplicate_of)
--   relisted          put up again after the earlier ad went (mark_relists)
--   sharp_changes     a price step of half or more up or down (a misread or
--                     a bait price)
--   missing_mileage   no mileage given
--   repeated          a used bike (1 000 km or more) posted twice on the
--                     same site (new bikes in stock are often identical ads)
--   dropped           the price went down from the first price we saw or
--                     the site's earlier price
create view public.dealer_reliability
with (security_invoker = true) as
with dealer_ads as (
  select l.*, lower(btrim(l.seller_name)) as dealer_key
  from public.listings l
  where l.seller_type = 'dealer'
    and nullif(btrim(l.seller_name), '') is not null
),
sharp as (
  select distinct s.listing_id
  from (
    select h.listing_id,
           h.price,
           lag(h.price) over (partition by h.listing_id
                              order by h.observed_at, h.id) as previous_price
    from public.listing_price_history h
  ) s
  where s.previous_price > 0
    and (s.price >= s.previous_price * 1.5 or s.price <= s.previous_price * 0.5)
)
select
  d.dealer_key,
  mode() within group (order by btrim(d.seller_name))        as seller_name,
  count(*) filter (where d.duplicate_of is null)             as bikes,
  count(*) filter (where d.duplicate_of is null
                     and d.status in ('active', 'price_changed')) as live,
  count(*) filter (where d.duplicate_of is null
                     and d.relisted_from is not null)        as relisted,
  count(*) filter (where d.duplicate_of is null
                     and d.id in (select listing_id from sharp)) as sharp_changes,
  count(*) filter (where d.duplicate_of is null
                     and d.mileage is null)                  as missing_mileage,
  count(*) filter (where d.duplicate_of is not null
                     and d.mileage >= 1000
                     and o.source = d.source)                as repeated,
  count(*) filter (where d.duplicate_of is null
                     and d.price < greatest(d.initial_price, d.price_before_drop)
                     )                                       as dropped,
  min(d.first_seen_at)                                       as first_seen_at
from dealer_ads d
left join public.listings o on o.id = d.duplicate_of
group by d.dealer_key;
