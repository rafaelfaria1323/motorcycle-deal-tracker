-- Mais › "Estado da recolha" (admins): how much space the database takes
-- (the Supabase free plan allows 500 MB; above it the project turns
-- read-only) and its biggest tables, indexes included.
create function public.database_usage()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'database_bytes', pg_catalog.pg_database_size(pg_catalog.current_database()),
    'tables', coalesce((
      select jsonb_agg(jsonb_build_object('name', t.name, 'bytes', t.bytes)
                       order by t.bytes desc, t.name)
      from (
        select c.relname::text as name, pg_catalog.pg_total_relation_size(c.oid) as bytes
        from pg_catalog.pg_class c
        where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'm')
        order by 2 desc, 1
        limit 5
      ) t
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.database_usage() from public, anon;
grant execute on function public.database_usage() to authenticated;
