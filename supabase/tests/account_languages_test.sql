insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000e2');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e1';
set local test.jwt = '{"is_anonymous": false}';

do $$
declare
  unsupported text;
begin
  assert not exists (select from public.account_languages),
    'legacy accounts need no row and retain Portuguese';
  insert into public.account_languages default values;
  assert (select language = 'pt' from public.account_languages),
    'an ordinary account preference defaults to Portuguese';

  insert into public.account_languages (language) values ('en')
  on conflict (user_id) do update set language = excluded.language;
  assert (select language = 'en' from public.account_languages),
    'the account can save English through the app upsert';

  foreach unsupported in array array['es', 'pt_PT', 'en_GB', 'EN', ''] loop
    begin
      update public.account_languages set language = unsupported
      where user_id = auth.uid();
      raise exception 'unsupported language was accepted: %', unsupported;
    exception when check_violation then null;
    end;
  end loop;
  begin
    update public.account_languages set language = null
    where user_id = auth.uid();
    raise exception 'a null language was accepted';
  exception when not_null_violation then null;
  end;
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000e2';
do $$
begin
  assert not exists (select from public.account_languages),
    'another account cannot read a language preference';
  update public.account_languages set language = 'pt'
  where user_id = '00000000-0000-0000-0000-0000000000e1';
  begin
    insert into public.account_languages (user_id, language)
    values ('00000000-0000-0000-0000-0000000000e1', 'pt')
    on conflict (user_id) do update set language = excluded.language;
    raise exception 'another account overwrote the preference';
  exception when insufficient_privilege then null;
  end;
  insert into public.account_languages (language) values ('pt');
  begin
    update public.account_languages
    set user_id = '00000000-0000-0000-0000-0000000000e1'
    where user_id = auth.uid();
    raise exception 'an account transferred its preference';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.account_languages where user_id = auth.uid();
    raise exception 'the app deleted a preference';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Anonymous sessions also use the authenticated role.
set local role authenticated;
set local test.jwt = '{"is_anonymous": true}';
do $$
begin
  assert not exists (select from public.account_languages),
    'an anonymous visitor sees no account preferences';
  begin
    insert into public.account_languages (language) values ('en')
    on conflict (user_id) do update set language = excluded.language;
    raise exception 'an anonymous visitor saved an account language';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
set local test.jwt = '{}';
do $$
begin
  assert not exists (select from public.account_languages),
    'a missing real-account claim cannot expose preferences';
end $$;
reset role;

set local role service_role;
do $$
begin
  assert (select count(*) from public.account_languages) = 2,
    'the collector can read both account languages';
end $$;
reset role;

do $$
begin
  assert (select language = 'en' from public.account_languages
          where user_id = '00000000-0000-0000-0000-0000000000e1'),
    'other accounts and visitors changed nothing';
  assert not has_table_privilege('anon', 'public.account_languages', 'select');
  assert not has_table_privilege('anon', 'public.account_languages', 'insert');
  assert not has_table_privilege('authenticated', 'public.account_languages', 'delete');
end $$;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000e1';
do $$
begin
  assert not exists (select from public.account_languages
                    where user_id = '00000000-0000-0000-0000-0000000000e1'),
    'account deletion removes its language preference';
  assert (select count(*) from public.account_languages) = 1,
    'deleting an account keeps the other preference';
end $$;
