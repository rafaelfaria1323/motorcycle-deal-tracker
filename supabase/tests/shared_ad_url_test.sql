-- B.2 (20261115210000_shared_ad_url.sql): the same ad shared with
-- different tracking waits once, under its address without tracking.
do $$
begin
  assert public.shared_ad_url('HTTPS://WWW.Facebook.com/marketplace/item/123/?ref=search&tracking=x#top')
         = 'https://www.facebook.com/marketplace/item/123/', 'Facebook: no query, no fragment';
  assert public.shared_ad_url('https://www.custojusto.pt/lisboa/motos/yamaha-mt-07-4567?utm_source=app')
         = 'https://www.custojusto.pt/lisboa/motos/yamaha-mt-07-4567', 'CustoJusto: no query';
  assert public.shared_ad_url('https://example.pt/ad?id=5&utm_source=x&fbclid=y&Ref=z#a')
         = 'https://example.pt/ad?id=5', 'elsewhere only the tracking goes';
  assert public.shared_ad_url('https://example.pt/ad?utm_medium=x')
         = 'https://example.pt/ad', 'nothing left: no "?"';
  assert public.shared_ad_url('https://example.pt/Ad/X') = 'https://example.pt/Ad/X',
    'the path keeps its case';
end $$;

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000005b1', false);

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005b1';
create temporary table url_key (key text) on commit drop;
grant all on url_key to anon, authenticated;
insert into url_key values (public.create_ad_import_key());

set local role anon;
do $$
declare
  v_key text := (select key from url_key);
begin
  perform public.receive_shared_ad(v_key,
    '{"url": "https://www.facebook.com/marketplace/item/9/?ref=share", "title": "Primeiro"}');
  perform public.receive_shared_ad(v_key,
    '{"url": "https://m.facebook.com/marketplace/item/9/?tracking=abc#x", "title": "De novo"}');
  perform public.receive_shared_ad(v_key,
    '{"url": "https://www.facebook.com/marketplace/item/9/?mibextid=q", "title": "Outra vez"}');
end $$;

reset role;
do $$
begin
  assert (select count(*) from public.shared_ads
          where user_id = '00000000-0000-0000-0000-0000000005b1') = 2,
    'www and m are two addresses, each waiting once';
  assert (select title from public.shared_ads
          where url = 'https://www.facebook.com/marketplace/item/9/') = 'Outra vez',
    'stored without tracking, the latest share kept';
end $$;
