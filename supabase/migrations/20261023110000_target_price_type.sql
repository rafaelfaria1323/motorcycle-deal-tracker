-- "Chegou ao seu preço" (15.19): a favourite's own price to pay, and an
-- alert when the listing drops to it. A new enum value can't be used in the
-- transaction that adds it, so the alerts come in the next migration.
alter type public.alert_type add value if not exists 'target_price_reached';

alter table public.listing_favourites
  add column target_price  numeric(10, 2) check (target_price > 0),
  add column target_set_at timestamptz;

-- Set by the database, so only prices seen after the target was set alert
-- (a target already above the price says nothing).
create function public.stamp_favourite_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.target_price is distinct from old.target_price then
    new.target_set_at := case when new.target_price is null then null else now() end;
  end if;
  return new;
end;
$$;

revoke all on function public.stamp_favourite_target() from public, anon, authenticated;

create trigger listing_favourites_target_stamp
  before insert or update of target_price on public.listing_favourites
  for each row execute function public.stamp_favourite_target();
