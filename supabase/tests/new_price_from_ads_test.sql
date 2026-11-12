-- The price of a new bike from the dealers' new bikes on sale (N.58): the
-- median of 3+ live dealer ads of this year's or last year's bike with
-- 100 km or less, nothing damaged; the typed price is only the fallback.

update public.motorcycles set new_price_reference = 8250 where slug = 'yamaha-mt-07';
update public.motorcycles set new_price_reference = 9500 where slug = 'honda-cb650r';

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, seller_name, location,
                             description, status)
select 'standvirtual', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       extract(year from now() at time zone 'Europe/Lisbon')::int - v.age,
       v.mileage, v.price, v.seller::public.seller_type, 'Stand ' || v.sid, 'Lisboa',
       v.description, v.status::public.listing_status
from public.motorcycles m,
     (values
       -- Three new MT-07s in shops: the median is 8 400 €.
       ('n1', 0,    0, 8300, 'dealer', null, 'active'),
       ('n2', 1,   10, 8400, 'dealer', null, 'price_changed'),
       ('n3', 0,  100, 8990, 'dealer', null, 'active'),
       -- None of these counts.
       ('used',    0,   101, 6000, 'dealer',  null, 'active'),
       ('old',     2,     0, 6000, 'dealer',  null, 'active'),
       ('nokm',    0,  null, 6000, 'dealer',  null, 'active'),
       ('private', 0,     0, 6000, 'private', null, 'active'),
       ('cheap',   0,     0,  100, 'dealer',  null, 'active'),
       ('gone',    0,     0, 6000, 'dealer',  null, 'removed'),
       ('dmg',     0,     0, 6000, 'dealer',  'Teve um toque por trás.', 'active'),
       ('foreign', 0,     0, 6000, 'dealer',  'Mota por legalizar.', 'active')
     ) v(sid, age, mileage, price, seller, description, status)
where m.slug = 'yamaha-mt-07';

-- Two new CB650Rs only: not enough, so the typed price stays.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, location, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       extract(year from now() at time zone 'Europe/Lisbon')::int, 0, 9000, 'dealer',
       'Lisboa', 'active'
from public.motorcycles m, (values ('cb1'), ('cb2')) v(sid)
where m.slug = 'honda-cb650r';

-- A copy of a new one on the other site doesn't count twice.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, seller_type, location, status,
                             duplicate_of)
select 'olx', 'n1-copy', 'https://x/n1-copy', motorcycle_id, brand, model, year,
       mileage, 20000, seller_type, location, status, id
from public.listings where source_listing_id = 'n1';

do $$
begin
  assert public.new_bike_ad(extract(year from now())::int, 0, 8000, 'dealer', null),
    'a dealer''s 0 km bike of this year is new';
  assert not public.new_bike_ad(extract(year from now())::int, 0, 8000, 'unknown', null),
    'a seller not known to be a dealer is not a shop';
  assert not public.new_bike_ad(extract(year from now())::int, 0, 8000, 'dealer',
                                '{cosmetic_damage}'),
    'a scratched one is not new';
  assert public.new_bike_ad(extract(year from now())::int, 0, 8000, 'dealer',
                            '{a2_limited}'),
    'an A2 version is still new';
end $$;

select public.refresh_new_prices_from_ads();

do $$
begin
  assert (select new_price_from_ads = 8400 and new_price_ad_count = 3
          from public.motorcycles where slug = 'yamaha-mt-07'),
    'the MT-07''s new price is the median of its three new ads';
  assert (select new_price_from_ads is null and new_price_ad_count is null
          from public.motorcycles where slug = 'honda-cb650r'),
    'two ads are not enough';
  assert (select new_price from public.listing_new_price_comparison c
          join public.listings l on l.id = c.listing_id
          where l.source_listing_id = 'used') = 8400,
    'the comparison prefers the ads'' price';
  assert (select new_price from public.listing_new_price_comparison c
          join public.listings l on l.id = c.listing_id
          where l.source_listing_id = 'cb1') = 9500,
    'and falls back on the typed one';
  assert public.refresh_new_prices_from_ads() = 0, 'nothing changes twice';
end $$;

-- Scoring refreshes first: one ad gone, the price is the typed one again,
-- and a nearly new bike is compared with it.
update public.listings set status = 'removed' where source_listing_id = 'n3';
update public.motorcycles set new_price_from_ads = null, new_price_ad_count = null
where slug = 'honda-cb650r';
select public.recalculate_deal_scores();

do $$
begin
  assert (select new_price_from_ads is null from public.motorcycles
          where slug = 'yamaha-mt-07'),
    'scoring refreshed the new price';
  assert (select (score_breakdown->>'new_price')::numeric
          from public.listings where source_listing_id = 'n1') = 8250,
    'a nearly new bike is compared with the typed price when the ads are too few';
end $$;

update public.listings set status = 'active' where source_listing_id = 'n3';
select public.recalculate_deal_scores();

do $$
begin
  assert (select (score_breakdown->>'new_price')::numeric
          from public.listings where source_listing_id = 'n1') = 8400,
    'and with the ads'' price when there are enough';
end $$;

-- Nobody but the database works it out.
set local role authenticated;
do $$
begin
  begin
    perform public.refresh_new_prices_from_ads();
    raise exception 'a user refreshed the new prices';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
