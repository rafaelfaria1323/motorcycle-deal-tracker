-- N.110b: the shortcut can be shared as one iCloud link for everyone.
-- Its script carries no key (version 2); the key, asked when the
-- shortcut is installed, comes in the header x-deal-tracker-key.
-- A script with the key in its body (version 1, or one made by hand)
-- still works.

create or replace function public.shared_ad_script_version()
returns integer
language sql
immutable
set search_path = ''
as $$ select 2 $$;

revoke all on function public.shared_ad_script_version() from public, anon, authenticated;

create or replace function public.receive_shared_ad(p_key text, p_ad jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
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
  -- The key from the body (a script with the key in it), else from the
  -- header x-deal-tracker-key (the shared shortcut: its script is the
  -- same for everyone, and the key is asked when it is installed).
  v_key := coalesce(
    nullif(btrim(p_key), ''),
    nullif(btrim(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-deal-tracker-key'), ''));
  select k.user_id into v_user from public.ad_import_keys k
  where k.key_hash = sha256(convert_to(coalesce(v_key, ''), 'UTF8'));
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
      then ' The shortcut has a new version: install it again from More › iPhone shortcut.'
      else ' O atalho tem uma versão nova: instale-o de novo em Mais › Atalho do iPhone.' end;
  end if;
  return jsonb_build_object(
    'message', v_message,
    'outdated', v_version < public.shared_ad_script_version(),
    'id', v_id);
end;
$$;

revoke all on function public.receive_shared_ad(text, jsonb) from public, anon, authenticated;
grant execute on function public.receive_shared_ad(text, jsonb) to anon, authenticated;
