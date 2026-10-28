-- "Examinar todas as fotos" (P.4): the photo step looks at the first 3
-- photos of each listing (P.1/P.2). A signed-in account can ask for every
-- photo of one ad (up to 30) to be shown to the image model too. The next
-- collection's photo step reads them first, from the photo CDN with the
-- same rules (2-3 s apart, at most 5 minutes a run), and the hints then
-- cover every photo. Hints only, never part of a score.

alter table public.listings
  add column photo_exam_requested_at timestamptz,
  add column photos_examined_all_at timestamptz;

comment on column public.listings.photo_exam_requested_at is
  'When someone first asked for every photo to be examined (request_photo_exam); null once done or never asked.';
comment on column public.listings.photos_examined_all_at is
  'When every photo was shown to the image model (P.4); null: only the first ones.';

-- Who asked for what, for the daily cap. RLS without policies: no API access.
create table public.photo_exam_requests (
  user_id      uuid not null references auth.users (id) on delete cascade,
  listing_id   uuid not null references public.listings (id) on delete cascade,
  requested_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create index photo_exam_requests_listing_idx on public.photo_exam_requests (listing_id);

alter table public.photo_exam_requests enable row level security;
revoke all on public.photo_exam_requests from anon, authenticated;

comment on table public.photo_exam_requests is
  'An account''s request to examine every photo of a listing (P.4); through request_photo_exam only.';

-- Asks for every photo of p_listing to be examined at the next collection;
-- returns when it was asked (the earliest request), or null when it was
-- already done. Only live listings of a collected model with more photos
-- than the 3 always examined; at most 5 new requests per account a day.
create function public.request_photo_exam(p_listing uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings%rowtype;
begin
  perform public.require_account();

  select l.* into v_listing
  from public.listings l
  join public.motorcycles m on m.id = l.motorcycle_id and m.is_active
  where l.id = p_listing
    and l.status in ('active', 'price_changed');
  if not found then
    raise exception 'Listing % is not collected or not live', p_listing
      using errcode = 'P0002';
  end if;
  if v_listing.photos_examined_all_at is not null then
    return null;
  end if;
  if cardinality(v_listing.images) <= 3 then
    raise exception 'Listing % has no photos beyond the first 3', p_listing
      using errcode = '22023';
  end if;

  if v_listing.photo_exam_requested_at is not null then
    return v_listing.photo_exam_requested_at;
  end if;

  if (select count(*) from public.photo_exam_requests r
      where r.user_id = auth.uid()
        and r.requested_at > now() - interval '1 day') >= 5 then
    raise exception 'At most 5 photo examinations a day'
      using errcode = '54000';
  end if;

  insert into public.photo_exam_requests (user_id, listing_id)
  values (auth.uid(), p_listing)
  on conflict (user_id, listing_id) do update set requested_at = now();

  update public.listings
  set photo_exam_requested_at = now()
  where id = p_listing;

  return now();
end;
$$;

revoke all on function public.request_photo_exam(uuid) from public, anon;
grant execute on function public.request_photo_exam(uuid) to authenticated;

-- The collector: the listings waiting for every photo to be examined,
-- oldest request first, with up to p_photos of their photos.
create function public.listings_awaiting_photo_exam(
  p_limit  integer default 20,
  p_photos integer default 30
)
returns table (id uuid, images text[])
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.images[1:p_photos]
  from public.listings l
  join public.motorcycles m on m.id = l.motorcycle_id and m.is_active
  where l.photo_exam_requested_at is not null
    and l.photos_examined_all_at is null
    and l.status in ('active', 'price_changed')
    and cardinality(l.images) > 0
  order by l.photo_exam_requested_at, l.id
  limit p_limit
$$;

revoke all on function public.listings_awaiting_photo_exam(integer, integer)
  from public, anon, authenticated;

-- The collector, once store_photo_features holds every photo of these
-- listings: their examination is done. Returns how many were marked.
create function public.finish_photo_exams(p_listings uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.listings
  set photos_examined_all_at = now(),
      photo_exam_requested_at = null
  where id = any (p_listings)
    and photo_exam_requested_at is not null;
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.finish_photo_exams(uuid[])
  from public, anon, authenticated;
