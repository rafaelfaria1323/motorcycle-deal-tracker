-- "Examinar todas as fotos" (P.4/P.7): an account asking for an ad that
-- someone else already asked for got the waiting request's time back but
-- left no row in photo_exam_requests, so photo_exam_answers never told it
-- when the examination was done (while the app said it would). It now
-- joins the waiting request: its row is stored, nothing new is started,
-- and the daily cap (5 new requests) isn't checked, since a join costs no
-- photo step of its own.
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
    -- Already waiting: this account is told too when it is done.
    insert into public.photo_exam_requests (user_id, listing_id)
    values (auth.uid(), p_listing)
    on conflict (user_id, listing_id) do nothing;
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
