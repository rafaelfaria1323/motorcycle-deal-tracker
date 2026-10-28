-- A classifier trained on the admins' marks (P.3): in the full-screen
-- photos an admin marks each of the first 3 photos (the ones the image
-- model saw, P.2) as a problem or fine. The collector trains a logistic
-- regression on those photos' stored embeddings (no photo again, no AI
-- service) and stores it here; every examined photo then gets its
-- probability as the hint code `learned`, beside the zero-shot codes.
-- Hints only, never part of a score.

create table public.photo_marks (
  user_id    uuid not null references auth.users (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  photo      smallint not null check (photo between 0 and 2),
  problem    boolean not null,
  marked_at  timestamptz not null default now(),
  primary key (user_id, listing_id, photo)
);

create index photo_marks_listing_idx on public.photo_marks (listing_id);

alter table public.photo_marks enable row level security;
revoke all on public.photo_marks from anon, authenticated;

comment on table public.photo_marks is
  'An admin''s mark on one of the first 3 photos of a listing (P.3); through set_photo_mark / my_photo_marks only.';

-- One classifier per image model: weights over its embedding (the
-- features' signed bytes / 127), the bias, what it learned from, and the
-- marks' state it was trained on (`marks_key`), so an unchanged set is not
-- trained again.
create table public.photo_classifiers (
  model      text primary key,
  weights    double precision[] not null,
  bias       double precision not null,
  samples    integer not null,
  problems   integer not null,
  accuracy   double precision,
  marks_key  text not null,
  trained_at timestamptz not null default now()
);

alter table public.photo_classifiers enable row level security;
revoke all on public.photo_classifiers from anon, authenticated;

comment on table public.photo_classifiers is
  'Logistic regression on the admins'' photo marks per image model (P.3); the collector only.';

-- An admin marks a photo (true: a problem, false: fine) or clears it (null).
create function public.set_photo_mark(p_listing uuid, p_photo integer, p_problem boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_photo is null or p_photo not between 0 and 2 then
    raise exception 'Only the first 3 photos can be marked' using errcode = '22023';
  end if;
  if p_problem is null then
    delete from public.photo_marks
    where user_id = auth.uid() and listing_id = p_listing and photo = p_photo;
  else
    insert into public.photo_marks (user_id, listing_id, photo, problem)
    values (auth.uid(), p_listing, p_photo, p_problem)
    on conflict (user_id, listing_id, photo)
      do update set problem = excluded.problem, marked_at = now();
  end if;
end;
$$;

revoke all on function public.set_photo_mark(uuid, integer, boolean) from public, anon;
grant execute on function public.set_photo_mark(uuid, integer, boolean) to authenticated;

-- The caller's marks on a listing's photos ([{photo, problem}]); empty for
-- anyone but an admin.
create function public.my_photo_marks(p_listing uuid)
returns table (photo integer, problem boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select m.photo::integer, m.problem
  from public.photo_marks m
  where m.user_id = auth.uid() and m.listing_id = p_listing and public.is_admin()
  order by m.photo
$$;

revoke all on function public.my_photo_marks(uuid) from public, anon;
grant execute on function public.my_photo_marks(uuid) to authenticated;

-- The marks to learn from for p_model: one row per marked photo it saw
-- (a photo two admins marked differently counts as a problem), and the
-- marks' state as `marks_key` (count and latest mark), with the key of the
-- classifier stored now (null: none).
create function public.photo_training_set(p_model text)
returns table (features text, problem boolean, marks_key text, trained_key text)
language sql
stable
security definer
set search_path = ''
as $$
  with marked as (
    select f.features, bool_or(m.problem) as problem, max(m.marked_at) as marked_at
    from public.photo_marks m
    join public.app_admins a on a.user_id = m.user_id
    join public.listing_photo_features f
      on f.listing_id = m.listing_id and f.photo = m.photo
    where f.model = p_model and f.features is not null
    group by f.listing_id, f.photo, f.features
  ),
  state as (
    select count(*) || '@' || coalesce(max(marked_at)::text, '') as k from marked
  )
  select encode(marked.features, 'base64'), marked.problem, state.k,
         (select c.marks_key from public.photo_classifiers c where c.model = p_model)
  from state left join marked on true
$$;

revoke all on function public.photo_training_set(text) from public, anon, authenticated;

-- The probability the classifier of the features' model gives a photo;
-- null without a classifier for it (or of another size).
create function public.photo_learned_share(p_model text, p_features bytea)
returns double precision
language sql
stable
set search_path = ''
as $$
  select 1 / (1 + exp(-least(greatest(
    c.bias + sum(
      (case when get_byte(p_features, i) > 127 then get_byte(p_features, i) - 256
            else get_byte(p_features, i) end)::double precision / 127
      * c.weights[i + 1]), -50), 50)))
  from public.photo_classifiers c
  cross join generate_series(0, length(p_features) - 1) i
  where c.model = p_model and cardinality(c.weights) = length(p_features)
  group by c.bias
$$;

revoke all on function public.photo_learned_share(text, bytea) from public, anon, authenticated;

-- The hints of these listings again from what is stored: the zero-shot
-- scores of each photo plus the classifier's `learned` share.
create function public.refresh_photo_hints(p_listings uuid[])
returns void
language sql
security definer
set search_path = ''
as $$
  update public.listings l
  set photo_hints = public.photo_hint_codes(coalesce((
    select jsonb_agg(jsonb_build_object(
      'photo', f.photo,
      'scores', f.scores || coalesce(jsonb_build_object('learned', round(
        public.photo_learned_share(f.model, f.features)::numeric, 3)), '{}')))
    from public.listing_photo_features f
    where f.listing_id = l.id
  ), '[]'))
  where l.id = any (p_listings)
$$;

revoke all on function public.refresh_photo_hints(uuid[]) from public, anon, authenticated;

-- As in 20261028180000, the hints now with the classifier's share.
create or replace function public.store_photo_features(p_model text, p_listings jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids uuid[] := array(select (e ->> 'id')::uuid from jsonb_array_elements(p_listings) e);
  n integer;
begin
  delete from public.listing_photo_features
  where listing_id = any (v_ids);

  insert into public.listing_photo_features (listing_id, photo, model, scores, features)
  select (e ->> 'id')::uuid, (p ->> 'photo')::smallint, p_model,
         coalesce(p -> 'scores', '{}'), decode(p ->> 'features', 'base64')
  from jsonb_array_elements(p_listings) e
  cross join lateral jsonb_array_elements(coalesce(e -> 'photos', '[]')) p
  on conflict (listing_id, photo) do nothing;

  update public.listings
  set photos_examined_at = now()
  where id = any (v_ids);
  get diagnostics n = row_count;

  perform public.refresh_photo_hints(v_ids);
  return n;
end;
$$;

-- Stores p_model's classifier and refreshes the hints of every listing it
-- applies to. Returns how many listings were refreshed.
create function public.store_photo_classifier(
  p_model    text,
  p_weights  double precision[],
  p_bias     double precision,
  p_samples  integer,
  p_problems integer,
  p_accuracy double precision,
  p_marks_key text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  insert into public.photo_classifiers
    (model, weights, bias, samples, problems, accuracy, marks_key)
  values (p_model, p_weights, p_bias, p_samples, p_problems, p_accuracy, p_marks_key)
  on conflict (model) do update
    set weights = excluded.weights, bias = excluded.bias,
        samples = excluded.samples, problems = excluded.problems,
        accuracy = excluded.accuracy, marks_key = excluded.marks_key,
        trained_at = now();

  v_ids := array(select distinct listing_id from public.listing_photo_features
                 where model = p_model);
  perform public.refresh_photo_hints(v_ids);
  return cardinality(v_ids);
end;
$$;

revoke all on function public.store_photo_classifier(
  text, double precision[], double precision, integer, integer, double precision, text)
  from public, anon, authenticated;
