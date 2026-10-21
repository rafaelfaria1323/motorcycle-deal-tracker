-- Space: the Supabase free plan allows 500 MB (above it the project turns
-- read-only). Once the database reaches p_limit_bytes (400 MB, where the
-- app's usage card turns red), gone listings of models nobody follows are
-- deleted, with their price history: removed or sold for at least
-- p_min_days, from the sites, and not a favourite, alerted, or the earlier
-- ad of a relist or duplicate. They would only matter again if someone
-- followed that model later (its market history would start shorter).
-- Postgres reuses the freed space but the file doesn't shrink, so the size
-- stays near the limit and each day deletes what has newly become
-- eligible. A deletion is told on Telegram.
create function public.prune_unfollowed_listings(
  p_limit_bytes bigint default 400 * 1024 * 1024,
  p_min_days integer default 30
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bytes bigint := pg_catalog.pg_database_size(pg_catalog.current_database());
  v_deleted integer;
begin
  if v_bytes < p_limit_bytes then
    return 0;
  end if;

  delete from public.listings l
  where l.status in ('removed', 'sold')
    and l.source in ('olx', 'standvirtual')
    and l.last_checked_at < now() - pg_catalog.make_interval(days => p_min_days)
    and not exists (select 1 from public.motorcycles m
                    where m.id = l.motorcycle_id and m.is_active)
    and not exists (select 1 from public.listing_favourites f where f.listing_id = l.id)
    and not exists (select 1 from public.alerts a where a.listing_id = l.id)
    and not exists (select 1 from public.listings o
                    where o.relisted_from = l.id or o.duplicate_of = l.id);
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    perform public.send_telegram(pg_catalog.format(
      '🧹 A base de dados chegou a %s MB (limite gratuito: 500 MB): foram apagados %s anúncios antigos de modelos que ninguém acompanha.',
      v_bytes / (1024 * 1024), v_deleted));
  end if;
  return v_deleted;
end;
$$;

revoke all on function public.prune_unfollowed_listings(bigint, integer)
  from public, anon, authenticated;

select cron.schedule(
  'prune-unfollowed-listings',
  '37 3 * * *',
  $job$ select public.prune_unfollowed_listings() $job$
);
