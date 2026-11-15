-- N.110: the iPhone shortcut "Avaliar no Deal Tracker".
--
-- Facebook Marketplace and CustoJusto are never read by us (N.98). The
-- shortcut goes round that honestly: the person opens the ad in Safari
-- and shares it; a small script in the shortcut reads what that Safari
-- is already showing (the link, the title, the description, the lines
-- that hold a price, a year, km or how long the ad has been up, and the
-- photos' addresses) and the shortcut sends it here with the account's
-- personal key. We never ask the site for anything.
--
-- The ad waits in the account's inbox (shared_ads, 7 days, at most 10)
-- until the person opens it in "Avaliar um anúncio", which fills the
-- typed ad's form with it; nothing becomes a listing. The key only drops
-- ads into its owner's inbox: it reads nothing. Only its SHA-256 is kept.
-- The script never sends the seller's name; phone numbers are removed on
-- the way in, as for every ad.

create table public.ad_import_keys (
  user_id uuid primary key references auth.users (id) on delete cascade,
  key_hash bytea not null unique,
  created_at timestamptz not null default now()
);

alter table public.ad_import_keys enable row level security;

create table public.shared_ads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  received_at timestamptz not null default now(),
  url text not null,
  title text,
  description text,
  price text,
  lines text[] not null default '{}',
  photos text[] not null default '{}',
  script_version integer not null,
  dismissed_at timestamptz
);

create index shared_ads_user on public.shared_ads (user_id, received_at);

alter table public.shared_ads enable row level security;

-- The script's current version: an older one still works, and the
-- shortcut's notification says to copy the new one.
create function public.shared_ad_script_version()
returns integer
language sql
immutable
set search_path = ''
as $$ select 1 $$;

revoke all on function public.shared_ad_script_version() from public, anon, authenticated;

-- A new key for the caller (the old one stops working); shown once.
-- Two random UUIDs: 244 random bits.
create function public.create_ad_import_key()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text := replace(gen_random_uuid()::text, '-', '')
                || replace(gen_random_uuid()::text, '-', '');
begin
  perform public.require_account();
  insert into public.ad_import_keys (user_id, key_hash, created_at)
  values (auth.uid(), sha256(convert_to(v_key, 'UTF8')), now())
  on conflict (user_id) do update
    set key_hash = excluded.key_hash, created_at = excluded.created_at;
  return v_key;
end;
$$;

revoke all on function public.create_ad_import_key() from public, anon, authenticated;
grant execute on function public.create_ad_import_key() to authenticated;

-- When the caller's key was made; null: none.
create function public.ad_import_key_created_at()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select k.created_at from public.ad_import_keys k where k.user_id = auth.uid()
$$;

revoke all on function public.ad_import_key_created_at() from public, anon, authenticated;
grant execute on function public.ad_import_key_created_at() to authenticated;

-- Turns the caller's key off.
create function public.remove_ad_import_key()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_account();
  delete from public.ad_import_keys where user_id = auth.uid();
end;
$$;

revoke all on function public.remove_ad_import_key() from public, anon, authenticated;
grant execute on function public.remove_ad_import_key() to authenticated;

-- What the shortcut calls (with the publishable key, so as anon): the
-- ad goes into the key's owner's inbox. Returns {message, outdated, id};
-- every refusal raises with a message the shortcut shows as it is.
create function public.receive_shared_ad(p_key text, p_ad jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_en boolean;
  v_url text;
  v_title text;
  v_version integer;
  v_lines text[];
  v_photos text[];
  v_id uuid;
  v_message text;
begin
  select k.user_id into v_user from public.ad_import_keys k
  where k.key_hash = sha256(convert_to(coalesce(p_key, ''), 'UTF8'));
  if v_user is null then
    raise exception 'Chave desconhecida: crie uma nova no Deal Tracker (Mais › Atalho do iPhone). / Unknown key: make a new one in Deal Tracker (More › iPhone shortcut).'
      using errcode = '28000';
  end if;
  v_en := exists (select 1 from public.account_languages l
                  where l.user_id = v_user and l.language = 'en');

  v_url := btrim(case when jsonb_typeof(p_ad) = 'object'
                      and jsonb_typeof(p_ad -> 'url') = 'string'
                      then p_ad ->> 'url' end);
  if v_url is null or v_url !~ '^https://[^\s]+$' or length(v_url) > 2000 then
    raise exception '%', case when v_en
      then 'This page has no link to send. Share the ad from Safari.'
      else 'Esta página não tem um endereço para enviar. Partilhe o anúncio a partir do Safari.' end
      using errcode = '22023';
  end if;

  -- Older than 7 days: gone, read or not (the day's count only needs one).
  delete from public.shared_ads s
  where s.user_id = v_user and s.received_at < now() - interval '7 days';

  if (select count(*) from public.shared_ads s
      where s.user_id = v_user and s.received_at > now() - interval '1 hour') >= 20
     or (select count(*) from public.shared_ads s
         where s.user_id = v_user and s.received_at > now() - interval '1 day') >= 100 then
    raise exception '%', case when v_en
      then 'Too many ads sent: wait a little and try again.'
      else 'Enviou anúncios demais: espere um pouco e tente de novo.' end
      using errcode = '54000';
  end if;
  -- The same ad sent again replaces the one waiting.
  delete from public.shared_ads s
  where s.user_id = v_user and s.url = v_url and s.dismissed_at is null;
  if (select count(*) from public.shared_ads s
      where s.user_id = v_user and s.dismissed_at is null) >= 10 then
    raise exception '%', case when v_en
      then '10 ads are already waiting: open "Check an ad" in Deal Tracker first.'
      else 'Já há 10 anúncios à espera: abra «Avaliar um anúncio» no Deal Tracker primeiro.' end
      using errcode = '54000';
  end if;

  v_title := nullif(left(btrim(public.without_phone_numbers(
    case when jsonb_typeof(p_ad -> 'title') = 'string' then p_ad ->> 'title' end)), 300), '');
  v_version := case when jsonb_typeof(p_ad -> 'version') = 'number'
                    then least(greatest((p_ad ->> 'version')::numeric, 0), 1000)::integer
                    else 0 end;
  select coalesce(array_agg(t.line order by t.n), '{}') into v_lines
  from (select left(btrim(public.without_phone_numbers(e.value)), 300) as line, e.n
        from jsonb_array_elements_text(
               case when jsonb_typeof(p_ad -> 'lines') = 'array' then p_ad -> 'lines'
                    else '[]' end) with ordinality as e (value, n)
        where e.n <= 60) t
  where t.line <> '';
  -- Each address once, in the page's order, the first 12.
  v_photos := array(
    select d.photo from (
      select distinct on (x.photo) x.photo, x.n
      from (select btrim(e.value #>> '{}') as photo, e.n
            from jsonb_array_elements(
                   case when jsonb_typeof(p_ad -> 'photos') = 'array' then p_ad -> 'photos'
                        else '[]' end) with ordinality as e (value, n)
            where jsonb_typeof(e.value) = 'string') x
      where x.photo ~ '^https://[^\s]+$' and length(x.photo) <= 2000
      order by x.photo, x.n) d
    order by d.n
    limit 12);

  insert into public.shared_ads
    (user_id, url, title, description, price, lines, photos, script_version)
  values (
    v_user, v_url, v_title,
    nullif(left(btrim(public.without_phone_numbers(
      case when jsonb_typeof(p_ad -> 'description') = 'string'
           then p_ad ->> 'description' end)), 5000), ''),
    nullif(left(btrim(case when jsonb_typeof(p_ad -> 'price') in ('string', 'number')
                           then p_ad ->> 'price' end), 40), ''),
    v_lines, v_photos, v_version)
  returning id into v_id;

  v_message := case when v_en
    then format('Sent to Deal Tracker: %s (%s photos).',
                coalesce(v_title, 'ad'), cardinality(v_photos))
    else format('Enviado para o Deal Tracker: %s (%s fotos).',
                coalesce(v_title, 'anúncio'), cardinality(v_photos)) end;
  if v_version < public.shared_ad_script_version() then
    v_message := v_message || case when v_en
      then ' The shortcut has a new script: copy it again in More › iPhone shortcut.'
      else ' O atalho tem um script novo: copie-o de novo em Mais › Atalho do iPhone.' end;
  end if;
  return jsonb_build_object(
    'message', v_message,
    'outdated', v_version < public.shared_ad_script_version(),
    'id', v_id);
end;
$$;

revoke all on function public.receive_shared_ad(text, jsonb) from public, anon, authenticated;
grant execute on function public.receive_shared_ad(text, jsonb) to anon, authenticated;

-- The caller's ads waiting, newest first.
create function public.my_shared_ads()
returns table (
  id uuid,
  received_at timestamptz,
  url text,
  title text,
  description text,
  price text,
  lines text[],
  photos text[],
  script_version integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.received_at, s.url, s.title, s.description, s.price, s.lines,
         s.photos, s.script_version
  from public.shared_ads s
  where s.user_id = auth.uid()
    and s.dismissed_at is null
    and s.received_at >= now() - interval '7 days'
  order by s.received_at desc, s.id
$$;

revoke all on function public.my_shared_ads() from public, anon, authenticated;
grant execute on function public.my_shared_ads() to authenticated;

-- Takes an ad out of the inbox (used or not wanted); it still counts for
-- the day's limit.
create function public.dismiss_shared_ad(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.shared_ads
  set dismissed_at = now()
  where id = p_id and user_id = auth.uid() and dismissed_at is null;
end;
$$;

revoke all on function public.dismiss_shared_ad(uuid) from public, anon, authenticated;
grant execute on function public.dismiss_shared_ad(uuid) to authenticated;
