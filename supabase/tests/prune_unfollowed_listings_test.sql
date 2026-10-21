-- Near the size limit, gone listings of models nobody follows are deleted;
-- anything still followed, live, recent, kept or referenced stays.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             price, status, last_checked_at)
select v.source, v.sid, 'https://x/' || v.sid,
       case v.model when 'followed' then (select id from public.motorcycles
                                          where is_active order by slug limit 1)
                    when 'unfollowed' then (select id from public.motorcycles
                                            where not is_active order by slug limit 1)
       end,
       'Honda', 'X', 5000, v.status::public.listing_status,
       now() - make_interval(days => v.days)
from (values
  ('olx',          'gone',       'none',       'removed', 40),
  ('standvirtual', 'sold',       'unfollowed', 'sold',    40),
  ('olx',          'followed',   'followed',   'removed', 40),
  ('olx',          'live',       'none',       'active',  40),
  ('olx',          'recent',     'none',       'removed', 10),
  ('manual',       'by-hand',    'none',       'removed', 40),
  ('olx',          'favourite',  'none',       'removed', 40),
  ('olx',          'alerted',    'none',       'removed', 40),
  ('olx',          'earlier-ad', 'none',       'removed', 40),
  ('olx',          'relist',     'none',       'active',   1)
) v(source, sid, model, status, days);

insert into public.listing_favourites (user_id, listing_id)
select '00000000-0000-0000-0000-0000000000c1', id from public.listings
where source_listing_id = 'favourite';
insert into public.alerts (user_id, listing_id, type)
select '00000000-0000-0000-0000-0000000000c1', id, 'new_listing' from public.listings
where source_listing_id = 'alerted';
update public.listings
set relisted_from = (select id from public.listings where source_listing_id = 'earlier-ad')
where source_listing_id = 'relist';

do $$
begin
  assert (select count(motorcycle_id) from public.listings
          where source_listing_id in ('followed', 'sold')) = 2,
    'one followed model and one nobody follows';
  assert public.prune_unfollowed_listings() = 0, 'below the limit: nothing';
  assert (select count(*) from public.listings) = 10, 'all still there';

  insert into vault.secrets values ('telegram_bot_token', 'tok'), ('telegram_chat_id', '42');
  assert public.prune_unfollowed_listings(0) = 2, 'at the limit: the two eligible ones';
  assert not exists (select from public.listings where source_listing_id in ('gone', 'sold')),
    'gone listings of models nobody follows are deleted';
  assert (select count(*) from public.listings) = 8, 'the rest stays';
  assert (select count(*) from net.calls
          where body ->> 'text' like '🧹 %foram apagados 2 anúncios antigos%') = 1,
    'told on Telegram';

  assert public.prune_unfollowed_listings(0) = 0, 'nothing left to delete';
  assert (select count(*) from net.calls) = 1, 'and nothing more to tell';

  assert exists (select from cron.job where jobname = 'prune-unfollowed-listings'
                 and schedule = '37 3 * * *'), 'scheduled daily';
end $$;

do $$
begin
  set local role authenticated;
  perform public.prune_unfollowed_listings(0);
  assert false, 'not callable from the app';
exception when insufficient_privilege then
  null;
end $$;
