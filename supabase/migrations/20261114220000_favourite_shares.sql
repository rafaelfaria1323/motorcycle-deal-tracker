-- Shared favourites (16.11): an account shows its favourites, with their
-- notes, checklists and visits, to one more account (a partner, a
-- mechanic), read only. The owner makes a link (`/#/share?code=…`, 14
-- days, one use); the account that opens it sees the list until either
-- stops it. A new link replaces the one not yet used; the account already
-- seeing the list keeps it until the new link is used.
create table public.favourite_shares (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  viewer_id uuid references auth.users (id) on delete cascade,
  code text unique,
  code_expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint favourite_shares_not_self check (viewer_id <> owner_id),
  constraint favourite_shares_code_expires
    check ((code is null) = (code_expires_at is null))
);

comment on table public.favourite_shares is
  'One account''s favourites shown to one more account, read only (16.11). No API access: through the functions below.';

create index favourite_shares_viewer_idx on public.favourite_shares (viewer_id);

alter table public.favourite_shares enable row level security;
revoke all on public.favourite_shares from anon, authenticated;

-- A new link for the caller's list (the one not yet used goes).
create function public.share_favourites() returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := translate(encode(uuid_send(gen_random_uuid()), 'base64'), '+/=', '-_');
begin
  perform public.require_account();
  insert into public.favourite_shares (owner_id, code, code_expires_at)
  values (auth.uid(), v_code, now() + interval '14 days')
  on conflict (owner_id) do update
    set code = excluded.code, code_expires_at = excluded.code_expires_at;
  return v_code;
end;
$$;

-- The caller's own share: who sees the list, and the link not yet used.
create function public.my_favourite_share()
returns table (viewer_email text, code text, code_expires_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select u.email::text, s.code,
         case when s.code_expires_at > now() then s.code_expires_at end
  from public.favourite_shares s
  left join auth.users u on u.id = s.viewer_id
  where s.owner_id = auth.uid()
$$;

-- Stops showing the caller's list to anyone, and forgets the link.
create function public.stop_sharing_favourites() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_account();
  delete from public.favourite_shares where owner_id = auth.uid();
end;
$$;

-- Opens a shared list: the caller sees it from now on. Returns the
-- owner's id. A link that is wrong, used, expired or the caller's own is
-- refused.
create function public.accept_favourite_share(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_owner uuid;
begin
  perform public.require_account();
  select owner_id into v_owner
  from public.favourite_shares
  where code = p_code and code_expires_at > now()
  for update;
  if v_owner is null then
    raise exception 'This link is not valid any more' using errcode = 'P0002';
  end if;
  if v_owner = auth.uid() then
    raise exception 'This is your own list' using errcode = '22023';
  end if;
  update public.favourite_shares
     set viewer_id = auth.uid(), code = null, code_expires_at = null
   where owner_id = v_owner;
  return v_owner;
end;
$$;

-- The lists shared with the caller.
create function public.favourites_shared_with_me()
returns table (owner_id uuid, owner_email text)
language sql stable security definer set search_path = '' as $$
  select s.owner_id, u.email::text
  from public.favourite_shares s
  join auth.users u on u.id = s.owner_id
  where s.viewer_id = auth.uid()
  order by u.email
$$;

-- Stops seeing a list shared with the caller.
create function public.leave_shared_favourites(p_owner uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_account();
  update public.favourite_shares
     set viewer_id = null
   where owner_id = p_owner and viewer_id = auth.uid();
end;
$$;

-- The favourites of a list shared with the caller, newest first, as rows
-- of listing_favourites (so the app embeds their listings as for its
-- own). Nothing when the list isn't shared with the caller.
create function public.shared_favourites(p_owner uuid)
returns setof public.listing_favourites
language sql stable security definer set search_path = '' as $$
  select f.*
  from public.listing_favourites f
  where f.user_id = p_owner
    and exists (
      select 1 from public.favourite_shares s
      where s.owner_id = p_owner and s.viewer_id = auth.uid()
    )
  order by f.created_at desc
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'share_favourites()', 'my_favourite_share()',
    'stop_sharing_favourites()', 'accept_favourite_share(text)',
    'favourites_shared_with_me()', 'leave_shared_favourites(uuid)',
    'shared_favourites(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
