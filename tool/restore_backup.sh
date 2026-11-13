#!/usr/bin/env bash
# Restores a backup made by tool/backup.sh into a database whose schema the
# migrations already made (tool/apply_migrations.sh on a new Supabase
# project; tool/db_test.sh with DB_TEST_MIGRATIONS_ONLY=1 in the weekly
# restore check):
#
#   tool/restore_backup.sh DB_URL BACKUP_DIR [--public-only]
#
# Empties every public table (the migrations' own rows: the catalog,
# places...), then loads the accounts (auth.users, auth.identities; skipped
# with --public-only, as the check's stand-in auth.users has other columns)
# and the public data, with triggers and foreign keys off for the load
# (session_replication_role = replica), so rows go back exactly as dumped.
# Then compares each table's rows with the counts dumped with it: a
# difference is a warning (a collection may have been writing). Stops at
# the first error.
set -euo pipefail

url=${1:?usage: restore_backup.sh DB_URL BACKUP_DIR [--public-only]}
dir=${2:?usage: restore_backup.sh DB_URL BACKUP_DIR [--public-only]}
mode=${3:-}
psql_db() { psql "$url" -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_db -c "do \$\$ declare t text; begin
  select string_agg(format('public.%I', tablename), ', ') into t
    from pg_tables where schemaname = 'public';
  if t is not null then execute 'truncate ' || t || ' cascade'; end if;
end \$\$" >/dev/null

load() {
  PGOPTIONS='-c session_replication_role=replica' \
    pg_restore --dbname="$url" --data-only --no-owner --exit-on-error \
      --single-transaction "$1"
}
[ "$mode" = "--public-only" ] || load "$dir/accounts.dump"
load "$dir/public.dump"

tables=0
differ=0
while IFS=$'\t' read -r t dumped; do
  tables=$((tables + 1))
  now=$(psql_db -At -c "select count(*) from public.\"$t\"")
  if [ "$now" != "$dumped" ]; then
    echo "::warning::$t: $now rows restored, $dumped counted when dumped"
    differ=$((differ + 1))
  fi
done < "$dir/counts.tsv"
listings=$(psql_db -At -c "select count(*) from public.listings")
echo "Restored $tables tables ($differ with a different count); listings: $listings."
