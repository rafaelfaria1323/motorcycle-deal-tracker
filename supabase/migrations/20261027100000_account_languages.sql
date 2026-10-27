-- One language for the account's interface, notifications and weekly summary.
-- An account without a preference keeps the original Portuguese behaviour.
create table public.account_languages (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  language text not null default 'pt',
  constraint account_languages_supported check (language in ('pt', 'en'))
);

alter table public.account_languages enable row level security;

revoke all on public.account_languages from public, anon, authenticated;
grant select, insert, update on public.account_languages to authenticated;

create policy "Accounts manage their own language"
  on public.account_languages
  for all to authenticated
  using (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  )
  with check (
    user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, true)
  );
