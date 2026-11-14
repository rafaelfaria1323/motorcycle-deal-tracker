-- What changed since the person last opened a favourite (N.97): each
-- favourite keeps how its ad was then (price, mileage, status), so
-- Favoritos and the ad's page can say "Desde a última vez que o abriu:
-- baixou 500 € · renovado no site". Set by the database from the listing,
-- so the app only writes seen_at (its value is replaced by now()).
alter table public.listing_favourites
  add column seen_at timestamptz,
  add column seen_price numeric(10,2),
  add column seen_mileage integer,
  add column seen_status public.listing_status;

comment on column public.listing_favourites.seen_at is
  'When the owner last opened the ad (N.97); seen_price, seen_mileage and seen_status are the ad then.';

create function public.stamp_favourite_seen()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.seen_at := now();
  select l.price, l.mileage, l.status
    into new.seen_price, new.seen_mileage, new.seen_status
    from public.listings l
   where l.id = new.listing_id;
  return new;
end;
$$;

revoke all on function public.stamp_favourite_seen() from public, anon, authenticated;

create trigger listing_favourites_seen_stamp
  before insert or update of seen_at on public.listing_favourites
  for each row execute function public.stamp_favourite_seen();

-- The favourites already kept start from today: nothing has changed yet.
update public.listing_favourites
   set seen_at = now()
 where true;
