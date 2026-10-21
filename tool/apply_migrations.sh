#!/usr/bin/env bash
# Applies the migrations the database does not have yet, the way
# `supabase db push` does, but with plain psql on the URL given, so it goes
# through the Session pooler. (The Supabase CLI rewrites a pooler URL to the
# direct db.<project>.supabase.co host, which is IPv6 only and unreachable
# from GitHub's runners.)
#
#   tool/apply_migrations.sh DB_URL [--dry-run]
#
# Applied migrations are listed in supabase_migrations.schema_migrations
# (version, name, statements), the CLI's own table, so `make db-push` and
# `supabase migration list` keep agreeing. Each migration runs in its own
# transaction together with its row in that table: a failing one changes
# nothing and stops the rest. Refuses to run when the database has a
# version the repository doesn't (someone applied a migration not on main).
set -euo pipefail

url=${1:?usage: apply_migrations.sh DB_URL [--dry-run]}
dry_run=${2:-}
dir=$(cd "$(dirname "$0")/.." && pwd)/supabase/migrations
psql_db() { psql "$url" -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_db -c "set client_min_messages = warning;
  create schema if not exists supabase_migrations;
  create table if not exists supabase_migrations.schema_migrations (
    version text primary key, statements text[], name text)" >/dev/null

applied=$(psql_db -At -c "select version from supabase_migrations.schema_migrations order by 1")
local_versions=$(for f in "$dir"/*.sql; do basename "$f" | cut -d_ -f1; done | sort)

unknown=$(comm -23 <(echo "$applied" | sed '/^$/d' | sort) <(echo "$local_versions"))
if [ -n "$unknown" ]; then
  echo "::error::The database has migrations that are not in supabase/migrations: ${unknown//$'\n'/ }. Add them to the repository (or repair the history) before applying more."
  exit 1
fi

pending=()
for f in "$dir"/*.sql; do
  version=$(basename "$f" | cut -d_ -f1)
  grep -qx "$version" <<<"$applied" || pending+=("$f")
done

if [ ${#pending[@]} -eq 0 ]; then
  echo "The database is up to date."
  exit 0
fi
echo "Migrations to apply:"
printf '  %s\n' "${pending[@]##*/}"
[ "$dry_run" = "--dry-run" ] && exit 0

for f in "${pending[@]}"; do
  name=$(basename "$f" .sql)
  version=${name%%_*}
  echo "Applying ${name}..."
  # One transaction: the migration and its row, or neither. Names are
  # checked by check_migrations.sh (<14 digits>_<a-z0-9_>), safe to quote.
  { cat "$f"; printf '\n;\ninsert into supabase_migrations.schema_migrations (version, name) values (%s, %s);\n' \
      "'$version'" "'${name#*_}'"; } \
    | psql_db --single-transaction -f - >/dev/null
done
echo "Applied ${#pending[@]} migration(s)."
