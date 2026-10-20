#!/usr/bin/env bash
# Applies every migration to a fresh Postgres database, then runs each
# supabase/tests/*_test.sql against it. A test fails by raising an error
# (plpgsql `assert` or `raise exception`); each test runs in a transaction
# that is rolled back, so tests don't see each other's rows.
#
# Uses the usual libpq variables (PGHOST, PGUSER, PGPASSWORD, ...); the
# database DB_TEST_NAME (default mdt_test) is dropped and recreated.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
db=${DB_TEST_NAME:-mdt_test}
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -d "$db" "$@"; }

psql -X -q -d postgres -c "drop database if exists $db" -c "create database $db"
psql_db -f "$root/supabase/tests/stubs.sql"

for f in "$root"/supabase/migrations/*.sql; do
  # pg_cron and pg_net exist only on Supabase; stubs.sql stands in for them.
  sed -E '/create extension if not exists (pg_cron|pg_net)/d' "$f" \
    | psql_db -f - >/dev/null || { echo "FAILED migration: $(basename "$f")"; exit 1; }
done
echo "Applied $(ls "$root"/supabase/migrations/*.sql | wc -l) migrations"

shopt -s nullglob
err=$(mktemp)
failed=0
for t in "$root"/supabase/tests/*_test.sql; do
  if { echo 'begin;'; cat "$t"; echo 'rollback;'; } \
      | psql_db -f - >/dev/null 2>"$err"; then
    echo "ok   $(basename "$t")"
  else
    echo "FAIL $(basename "$t")"; sed 's/^/     /' "$err"
    failed=1
  fi
done
exit $failed
