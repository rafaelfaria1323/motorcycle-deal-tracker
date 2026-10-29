-- "Examinar todas as fotos" (P.4) no longer waits for the next collection:
-- a new request starts photos.yml (the photo step on its own: the photo
-- CDN only, never a page of either site, with the same rules), which
-- examines the waiting requests first. The step still runs after every
-- collection, which picks up a request whose start was lost. Once done,
-- each account that asked is told on its devices (photo_exam_answers).
-- The request cap (5 new a day per account) also caps the starts.

create or replace function public.dispatch_workflow(p_workflow text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  if p_workflow not in ('collect.yml', 'weekly-summary.yml', 'photos.yml') then
    raise exception 'unknown workflow %', p_workflow;
  end if;

  select s.decrypted_secret into token
  from vault.decrypted_secrets s
  where s.name = 'github_dispatch_token';

  if token is null then
    raise warning 'github_dispatch_token is not in the Vault; % not started',
      p_workflow;
    return null;
  end if;

  return net.http_post(
    url := 'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
           || '/actions/workflows/' || p_workflow || '/dispatches',
    body := '{"ref": "main"}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || token,
      'Accept', 'application/vnd.github+json',
      'Content-Type', 'application/json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent', 'motorcycle-deal-tracker'
    ),
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function public.dispatch_workflow(text)
  from public, anon, authenticated;

-- As before, plus: a new request starts the photo step now (pg_net sends
-- it after the commit; a failed start leaves the request for the next
-- collection).
create or replace function public.request_photo_exam(p_listing uuid)
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

  perform public.dispatch_workflow('photos.yml');

  return now();
end;
$$;

revoke all on function public.request_photo_exam(uuid) from public, anon;
grant execute on function public.request_photo_exam(uuid) to authenticated;

-- The collector, after finish_photo_exams: who asked for these listings'
-- photos, with the bike and how many kinds of hint its photos now show,
-- for the notification. A listing can be asked for only until it is done,
-- so every request of a finished listing belongs to that examination.
create function public.photo_exam_answers(p_listings uuid[])
returns table (
  user_id    uuid,
  listing_id uuid,
  brand      text,
  model      text,
  year       integer,
  hints      integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.user_id, l.id, l.brand::text, l.model::text, l.year::integer,
         (select count(distinct h ->> 'code')::integer
          from jsonb_array_elements(l.photo_hints) h)
  from public.photo_exam_requests r
  join public.listings l on l.id = r.listing_id
  join auth.users u on u.id = r.user_id
  where r.listing_id = any (p_listings)
    and l.photos_examined_all_at is not null
    and not coalesce(u.is_anonymous, false)
  order by r.requested_at, r.user_id
$$;

revoke all on function public.photo_exam_answers(uuid[])
  from public, anon, authenticated;
