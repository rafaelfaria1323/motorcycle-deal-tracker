-- N.124: a favourite whose ad has been gone a day leaves the list; a live
-- ad, or one gone less than a day (maybe back on the next read), stays.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000f4');

do $$
declare
  v_user uuid := '00000000-0000-0000-0000-0000000000f4';
  v_live uuid;
  v_gone uuid;
  v_recent uuid;
  v_sold uuid;
begin
  insert into public.listings (source, source_listing_id, url, brand, model, price, status, last_seen_at)
  values ('olx', 'pgf-live', 'https://www.olx.pt/d/a/pgf-live', 'Yamaha', 'R7', 9000, 'active', now() - interval '3 days')
  returning id into v_live;
  insert into public.listings (source, source_listing_id, url, brand, model, price, status, last_seen_at)
  values ('olx', 'pgf-gone', 'https://www.olx.pt/d/a/pgf-gone', 'Yamaha', 'R7', 9000, 'removed', now() - interval '2 days')
  returning id into v_gone;
  insert into public.listings (source, source_listing_id, url, brand, model, price, status, last_seen_at)
  values ('olx', 'pgf-recent', 'https://www.olx.pt/d/a/pgf-recent', 'Yamaha', 'R7', 9000, 'removed', now() - interval '3 hours')
  returning id into v_recent;
  insert into public.listings (source, source_listing_id, url, brand, model, price, status, last_seen_at)
  values ('olx', 'pgf-sold', 'https://www.olx.pt/d/a/pgf-sold', 'Yamaha', 'R7', 9000, 'sold', now() - interval '30 hours')
  returning id into v_sold;

  insert into public.listing_favourites (user_id, listing_id, note)
  select v_user, id, 'nota' from unnest(array[v_live, v_gone, v_recent, v_sold]) id;

  assert public.prune_gone_favourites() = 2, 'the two gone a day or more';
  assert (select array_agg(listing_id order by listing_id)
          from public.listing_favourites where user_id = v_user)
         = (select array_agg(id order by id) from unnest(array[v_live, v_recent]) id),
    'the live one and the one gone a few hours stay';
  assert exists (select 1 from public.listings where id = v_gone),
    'the listing itself stays';
  assert public.prune_gone_favourites() = 0, 'nothing more the second time';
  assert public.prune_gone_favourites(now() + interval '1 day') = 1,
    'a day on, the recent one goes too';
end $$;

do $$
begin
  assert exists (select 1 from cron.job where jobname = 'prune-gone-favourites'),
    'scheduled';
end $$;
