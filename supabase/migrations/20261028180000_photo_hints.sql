-- Photo hints (P.2): the photos bin/photos.dart already downloads for
-- their fingerprints (P.1) are also shown to a free image model run on the
-- collector's runner (CLIP ViT-B/32, tool/photo_examine.py; no extra
-- request, no third party). It says how much each photo looks like a
-- crashed or fallen bike, scratches, broken or missing parts or rust, or
-- like a bike in good condition. The hints are shown on the listing page
-- as things to look at in the photos, never part of a score.

alter table public.listings
  add column photos_examined_at timestamptz,
  add column photo_hints jsonb not null default '[]';

comment on column public.listings.photos_examined_at is
  'When the first photos were shown to the image model (listing_photo_features); null: not yet.';
comment on column public.listings.photo_hints is
  'What the photos may show ([{code, photo, p}], photo_hint_codes): hints only, never part of a score.';

-- One row per photo examined. `scores` = the model's share of each code;
-- `features` = the photo's embedding (512 signed bytes), so a classifier
-- trained later on Rafael's marks (P.3) needs no photo again.
create table public.listing_photo_features (
  listing_id uuid not null references public.listings (id) on delete cascade,
  photo      smallint not null,
  model      text not null,
  scores     jsonb not null,
  features   bytea,
  primary key (listing_id, photo)
);

alter table public.listing_photo_features enable row level security;
revoke all on public.listing_photo_features from anon, authenticated;

comment on table public.listing_photo_features is
  'What the image model saw in the first photos of a listing (bin/photos.dart); the collector only.';

-- The hints in a listing's photos ([{photo, scores}]): each problem code
-- one photo gives at least half of its share to, with its likeliest photo
-- (from 0), likeliest first. `ok` and `other` are the alternatives, never
-- hints. The threshold lives here so it can be retuned on the stored
-- scores (update listings from listing_photo_features).
create function public.photo_hint_codes(p_photos jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object('code', code, 'photo', photo, 'p', p)
    order by p desc, code
  ), '[]')
  from (
    select distinct on (s.key)
      s.key as code,
      (e ->> 'photo')::integer as photo,
      round((s.value #>> '{}')::numeric, 2) as p
    from jsonb_array_elements(coalesce(p_photos, '[]')) e
    cross join lateral jsonb_each(coalesce(e -> 'scores', '{}')) s
    where s.key not in ('ok', 'other')
      and jsonb_typeof(s.value) = 'number'
      and (s.value #>> '{}')::numeric >= 0.5
    order by s.key, (s.value #>> '{}')::numeric desc, (e ->> 'photo')::integer
  ) best
$$;

revoke all on function public.photo_hint_codes(jsonb)
  from public, anon, authenticated;

-- As listings_missing_photo_hashes (20261028170000), and with p_examine
-- also the listings fingerprinted before the image model came in (or while
-- it was off): those not fingerprinted first.
create function public.listings_missing_photo_checks(
  p_limit   integer default 200,
  p_photos  integer default 3,
  p_examine boolean default false
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
  where l.status in ('active', 'price_changed')
    and (l.photos_hashed_at is null
         or (p_examine and l.photos_examined_at is null))
    and cardinality(l.images) > 0
    and (l.source <> 'standvirtual'
         or l.photos_read_at is not null
         or l.details_failed_at is not null)
  order by l.photos_hashed_at is null desc, l.duplicate_of is null desc,
           l.first_seen_at desc, l.id
  limit p_limit
$$;

revoke all on function public.listings_missing_photo_checks(integer, integer, boolean)
  from public, anon, authenticated;

-- Stores what p_model saw in each listing of p_listings ([{id, photos:
-- [{photo, scores, features}]}], features in base64) in place of what was
-- stored before, and the listing's hints. Returns how many listings were
-- stored.
create function public.store_photo_features(p_model text, p_listings jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  delete from public.listing_photo_features
  where listing_id in (
    select (e ->> 'id')::uuid from jsonb_array_elements(p_listings) e
  );

  insert into public.listing_photo_features (listing_id, photo, model, scores, features)
  select (e ->> 'id')::uuid, (p ->> 'photo')::smallint, p_model,
         coalesce(p -> 'scores', '{}'), decode(p ->> 'features', 'base64')
  from jsonb_array_elements(p_listings) e
  cross join lateral jsonb_array_elements(coalesce(e -> 'photos', '[]')) p
  on conflict (listing_id, photo) do nothing;

  update public.listings l
  set photos_examined_at = now(),
      photo_hints = public.photo_hint_codes(e -> 'photos')
  from jsonb_array_elements(p_listings) e
  where l.id = (e ->> 'id')::uuid;
  get diagnostics n = row_count;

  return n;
end;
$$;

revoke all on function public.store_photo_features(text, jsonb)
  from public, anon, authenticated;
