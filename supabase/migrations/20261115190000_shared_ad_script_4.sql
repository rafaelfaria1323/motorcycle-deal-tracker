-- N.110c: script 4 of the iPhone shortcut sends the ad's description
-- whole (the opened "Ver mais" block, line breaks kept) in `description`;
-- shortcuts with script 3 are told to update.
create or replace function public.shared_ad_script_version()
returns integer
language sql
immutable
set search_path = ''
as $$ select 4 $$;

revoke all on function public.shared_ad_script_version() from public, anon, authenticated;
