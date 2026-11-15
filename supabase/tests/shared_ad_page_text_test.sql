-- Script 3 and the clean-up (20261115180000_shared_ad_page_text.sql).
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000005b1', false);

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005b1';
create temporary table keys (key text) on commit drop;
grant all on keys to anon, authenticated;
do $$
begin
  insert into keys values (public.create_ad_import_key());
end $$;

reset test.uid;
reset test.jwt;
set local role anon;
do $$
declare
  v_result jsonb;
begin
  v_result := public.receive_shared_ad((select key from keys), jsonb_build_object(
    'version', 4,
    'url', 'https://www.facebook.com/marketplace/item/9/',
    'title', 'Honda CB650R',
    'price', '6 900 €',
    'old_price', '7 400 €',
    'text', E'Honda CB650R\n6 900 €\nCondução: 18 000 km\nÚnico dono. Ligue 912 345 678.\n' || repeat('x', 9000)));
  assert not (v_result ->> 'outdated')::boolean, 'script 3 is current';
end $$;

set local role authenticated;
set local test.jwt = '{"is_anonymous": false}';
set local test.uid = '00000000-0000-0000-0000-0000000005b1';
do $$
declare
  r record;
begin
  select * into r from public.my_shared_ads();
  assert r.old_price = '7 400 €', 'the price before the drop';
  assert r.page_text like E'Honda CB650R\n6 900 €\nCondução: 18 000 km\nÚnico dono.%', 'the page text';
  assert r.page_text not like '%912%', 'no phone number in it';
  assert length(r.page_text) = 8000, 'at most 8000 characters';
  perform public.dismiss_shared_ad(r.id);
end $$;

reset role;
do $$
declare
  r record;
begin
  select * into r from public.shared_ads
  where user_id = '00000000-0000-0000-0000-0000000005b1';
  assert r.dismissed_at is not null, 'dismissed';
  assert r.page_text is null and r.title is null and r.old_price is null
         and r.price is null and r.photos = '{}' and r.lines = '{}',
    'a dismissed ad keeps only its link and time';
  assert r.url = 'https://www.facebook.com/marketplace/item/9/', 'the link stays for the limits';

  -- The daily job: dismissed a day ago, or 7 days old, goes.
  insert into public.shared_ads (user_id, url, script_version, received_at, dismissed_at) values
    ('00000000-0000-0000-0000-0000000005b1', 'https://x.pt/old', 3, now() - interval '8 days', null),
    ('00000000-0000-0000-0000-0000000005b1', 'https://x.pt/waiting', 3, now() - interval '3 days', null),
    ('00000000-0000-0000-0000-0000000005b1', 'https://x.pt/used', 3, now() - interval '2 days', now());
  assert public.prune_shared_ads() = 2, 'two deleted';
  assert (select array_agg(url order by url) from public.shared_ads
          where user_id = '00000000-0000-0000-0000-0000000005b1')
         = array['https://www.facebook.com/marketplace/item/9/', 'https://x.pt/waiting'],
    'today''s dismissed ad and the one still waiting stay';
  assert exists (select 1 from cron.job where jobname = 'prune-shared-ads'
                 and command like '%prune_shared_ads()%'), 'scheduled daily';
end $$;
