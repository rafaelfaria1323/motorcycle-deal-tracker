-- N.61 (20261112110000_likely_sales.sql): how a gone ad left the market,
-- exit prices from likely sales only, and the weekly score check.

-- The seller says it is sold or reserved.
do $$
begin
  assert public.sold_in_text('MT-07 VENDIDA', null), 'in the title';
  assert public.sold_in_text('MT 07 - Reservada', null), 'reserved';
  assert public.sold_in_text(null, 'VENDIDA!!! Obrigado a todos.'), 'opening the text';
  assert public.sold_in_text(null, 'Mota em bom estado. Já vendida, obrigado.'), 'já vendida';
  assert public.sold_in_text(null, 'Revisões feitas. Neste momento está reservada.'), 'está reservada';
  assert public.sold_in_text('MT-07 sold', null), 'in English';

  assert not public.sold_in_text('MT-07 ABS', 'Vendo mota em bom estado.'), 'vendo is to sell';
  assert not public.sold_in_text(null, 'Vendida com garantia de 12 meses.'), 'how it is sold';
  assert not public.sold_in_text(null, 'Vendido no estado em que se encontra.'), 'as is';
  assert not public.sold_in_text(null, 'Mota vendida c/ garantia.'), 'c/';
  assert not public.sold_in_text(
    null, 'Mota impecável, sempre em garagem, revisões na marca. Será vendida com IUC pago.'),
    'later in the text, how it is sold';
  assert not public.sold_in_text(null, 'Bom estado, mas atenção: ainda não está vendida.'),
    'a denial';
  assert not public.sold_in_text(
    null, 'Comprei a mota em 2021, foi vendida pela marca com a revisão feita.'),
    'the bike''s history, past the opening';
  assert not public.sold_in_text(null, null), 'no text';
end $$;

-- The trigger marks it, and clears the mark when the text changes back.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             variant, price)
select 'olx', 'ls-mark', 'https://x/ls-mark', m.id, m.brand, m.model, 'MT-07 VENDIDA', 6000
from public.motorcycles m where m.slug = 'yamaha-mt-07';
do $$
begin
  assert (select sold_marked_at is not null from public.listings
          where source_listing_id = 'ls-mark'), 'marked on the way in';
  update public.listings set variant = 'MT-07' where source_listing_id = 'ls-mark';
  assert (select sold_marked_at is null from public.listings
          where source_listing_id = 'ls-mark'), 'cleared: the sale fell through';
  update public.listings set description = 'Já vendida.' where source_listing_id = 'ls-mark';
  assert (select sold_marked_at is not null from public.listings
          where source_listing_id = 'ls-mark'), 'marked again from the description';
end $$;

-- The 30 days on the site.
do $$
declare
  t timestamptz := '2026-11-01 12:00+00';
begin
  assert public.ended_at_expiry(t - interval '30 days', null, t), 'at 30 days';
  assert public.ended_at_expiry(t - interval '29 days', null, t), 'a day before';
  assert public.ended_at_expiry(t - interval '61 days', null, t), 'after one renewal';
  assert public.ended_at_expiry(t - interval '50 days', t - interval '30 days', t),
    'from the last renewal';
  assert not public.ended_at_expiry(t - interval '20 days', null, t), 'midway';
  assert not public.ended_at_expiry(t - interval '2 days', null, t), 'not at day 0';
  assert not public.ended_at_expiry(t - interval '45 days', t - interval '10 days', t),
    'neither date fits';
  assert not public.ended_at_expiry(null, null, t), 'no dates';
end $$;

-- Gone ads of the MT-07, one of each kind, and a live one.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             variant, year, mileage, price, status, seller_type,
                             published_at, first_seen_at, last_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, v.variant,
       2020, 20000, v.price, v.status::public.listing_status,
       v.seller::public.seller_type,
       now() - make_interval(days => v.published),
       now() - make_interval(days => v.published),
       now() - make_interval(days => least(v.published, 5))
from public.motorcycles m,
     (values ('ls-sold', 'MT-07 Vendida', 7000, 'removed', 'private', 40),
             ('ls-gone', 'MT-07', 6000, 'removed', 'private', 20),
             ('ls-dealer', 'MT-07', 6400, 'removed', 'dealer', 35),
             ('ls-expired', 'MT-07', 9000, 'removed', 'private', 35),
             ('ls-back', 'MT-07', 9000, 'removed', 'private', 20),
             ('ls-twin', 'MT-07', 9000, 'removed', 'private', 20),
             ('ls-live', 'MT-07', 6500, 'active', 'private', 3),
             ('ls-once', 'MT-07', 3000, 'removed', 'private', 0)
     ) v(sid, variant, price, status, seller, published)
where m.slug = 'yamaha-mt-07';
-- ls-back came back; ls-twin is still on sale on the other site.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, relisted_from)
select 'olx', 'ls-relist', 'https://x/ls-relist', m.id, m.brand, m.model, 2020, 20000,
       9000, (select id from public.listings where source_listing_id = 'ls-back')
from public.motorcycles m where m.slug = 'yamaha-mt-07';
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, duplicate_of)
select 'standvirtual', 'ls-copy', 'https://x/ls-copy', m.id, m.brand, m.model, 2020, 20000,
       9000, (select id from public.listings where source_listing_id = 'ls-twin')
from public.motorcycles m where m.slug = 'yamaha-mt-07';

do $$
declare
  kinds jsonb := (
    select jsonb_object_agg(l.source_listing_id, public.exit_kind(l))
    from public.listings l where l.source_listing_id like 'ls-%');
  mt07 uuid := (select id from public.motorcycles where slug = 'yamaha-mt-07');
  v record;
begin
  assert kinds ->> 'ls-sold' = 'sold_in_text', format('sold: %s', kinds);
  assert kinds ->> 'ls-gone' = 'likely_sold', format('gone: %s', kinds);
  assert kinds ->> 'ls-dealer' = 'likely_sold', format('dealers don''t expire: %s', kinds);
  assert kinds ->> 'ls-expired' = 'expired', format('expired: %s', kinds);
  assert kinds ->> 'ls-back' = 'relisted', format('relisted: %s', kinds);
  assert kinds ->> 'ls-twin' = 'still_listed', format('elsewhere: %s', kinds);
  assert kinds ->> 'ls-once' = 'seen_once', format('one run saw it: %s', kinds);
  assert kinds -> 'ls-live' = 'null'::jsonb, format('live: %s', kinds);

  -- Exit prices count only the likely sales: 6000, 6400 and 7000.
  select * into v from public.exit_price(mt07, 2020, 20000);
  assert v.gone_count = 3, format('three likely sales, got %s', v.gone_count);
  assert v.median_price = 6400, format('median 6400, got %s', v.median_price);
end $$;

-- The weekly check.
update public.listings
set last_pct_below_market = v.position, initial_price = v.initial
from (values ('ls-sold', -10.0, 7500), ('ls-gone', 4.0, 6000),
             ('ls-dealer', -2.0, 6400)) v(sid, position, initial)
where source_listing_id = v.sid;

do $$
declare
  r record;
begin
  select * into r from public.score_check_models(28) where model = 'Yamaha MT-07';
  assert r.gone = 7, format('seven gone, got %s', r.gone);
  assert r.sold_in_text = 1 and r.likely_sold = 2 and r.relisted = 1
     and r.still_listed = 1 and r.expired = 1 and r.seen_once = 1,
    format('the kinds: %s', r);
  assert r.sold_with_position = 3 and r.sold_position = -2.0,
    format('the sales'' median position: %s', r);
  -- Drops: 1 - 7000/7500 = 6.7 %, then 0 and 0: one dropped, and the
  -- median is of that one (over all three it was 0, N.95).
  assert r.sold_dropped = 1, format('one dropped: %s', r.sold_dropped);
  assert r.sold_drop_pct = 6.7, format('median drop: %s', r.sold_drop_pct);
  assert r.sold_days = 30, format('median days up: %s', r.sold_days);
end $$;

-- Bands: scored ads first seen 20 days ago, one sold within 14 days.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, status, first_seen_at, last_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model, 2020, 20000, 6000,
       v.status::public.listing_status, now() - interval '20 days',
       now() - make_interval(days => v.seen)
from public.motorcycles m,
     (values ('lb-fast', 'removed', 15), ('lb-slow', 'removed', 1),
             ('lb-live', 'active', 0), ('lb-low', 'active', 0)) v(sid, status, seen)
where m.slug = 'yamaha-mt-07';
update public.listings set deal_score = 85
where source_listing_id in ('lb-fast', 'lb-slow', 'lb-live');
update public.listings set deal_score = 30 where source_listing_id = 'lb-low';
-- Cleared once gone, as recalculate_deal_scores does: the last one stays.
update public.listings set deal_score = null
where source_listing_id in ('lb-fast', 'lb-slow');

do $$
declare
  r record;
begin
  assert (select last_deal_score from public.listings where source_listing_id = 'lb-fast') = 85,
    'the last Deal Score is kept';
  select * into r from public.score_check_bands(60, 14, '-infinity') where band = '80-100';
  assert r.ads = 3 and r.sold_within = 1 and r.share = 33.3, format('top band: %s', r);
  select * into r from public.score_check_bands(60, 14, '-infinity') where band = '0-39';
  assert r.ads = 1 and r.sold_within = 0, format('bottom band: %s', r);
  -- Ads found before last Deal Scores were kept are left out (N.92).
  assert not exists (
    select 1 from public.score_check_bands(60, 14, now() - interval '19 days')),
    'only ads found since p_since';
end $$;

set local role authenticated;
do $$
begin
  perform public.score_check_models(28);
  assert false, 'the app read the check';
exception when insufficient_privilege then null;
end $$;
do $$
begin
  assert has_function_privilege('anon', 'public.exit_kind(public.listings)', 'execute'),
    'visitors can read how an ad left';
end $$;
reset role;
