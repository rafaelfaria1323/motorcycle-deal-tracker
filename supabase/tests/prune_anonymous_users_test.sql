-- Anonymous users idle for 30 days are deleted; accounts never are.
insert into auth.users (id, is_anonymous, created_at) values
  ('00000000-0000-0000-0000-0000000000f1', true,  now() - interval '40 days'),  -- idle, no session
  ('00000000-0000-0000-0000-0000000000f2', true,  now() - interval '40 days'),  -- idle session
  ('00000000-0000-0000-0000-0000000000f3', true,  now() - interval '40 days'),  -- refreshed lately
  ('00000000-0000-0000-0000-0000000000f4', true,  now() - interval '5 days'),   -- new
  ('00000000-0000-0000-0000-0000000000f5', false, now() - interval '400 days'); -- an account
insert into auth.sessions (user_id, created_at, updated_at, refreshed_at) values
  ('00000000-0000-0000-0000-0000000000f2', now() - interval '40 days', now() - interval '35 days', null),
  ('00000000-0000-0000-0000-0000000000f3', now() - interval '40 days', now() - interval '40 days',
   (now() - interval '2 days') at time zone 'utc'),
  ('00000000-0000-0000-0000-0000000000f5', now() - interval '400 days', now() - interval '400 days', null);

do $$
begin
  assert public.prune_anonymous_users() = 2, 'the two idle anonymous users';
  assert (select array_agg(right(id::text, 2) order by id) from auth.users
          where id::text like '00000000-0000-0000-0000-0000000000f%') = array['f3', 'f4', 'f5'];
  assert (select count(*) from auth.sessions
          where user_id = '00000000-0000-0000-0000-0000000000f2') = 0, 'its sessions went too';
  assert public.prune_anonymous_users() = 0, 'nothing left to prune';

  assert (select schedule from cron.job where jobname = 'prune-anonymous-users') = '43 3 * * *';
  assert not has_function_privilege('authenticated', 'public.prune_anonymous_users(integer)', 'execute');
  assert not has_function_privilege('anon', 'public.prune_anonymous_users(integer)', 'execute');
end $$;
