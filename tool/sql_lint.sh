#!/usr/bin/env bash
# Static checks of the database, without AI. Run after `make db-test`
# (it reads the database db_test.sh left behind, every migration applied):
#   1. plpgsql_check: every PL/pgSQL function in public (trigger functions
#      with their table) is compiled against the real tables, so a wrong
#      column, type or unused variable fails even on a path no test runs.
#   2. splinter (Supabase's database linter, the dashboard's "Advisors"):
#      missing row level security, exposed functions, unindexed foreign
#      keys, duplicate indexes... Findings that are on purpose are listed
#      with their reason in supabase/lint_allow.txt.
#   3. squawk on the migrations this branch adds (not on main yet): only
#      the rules for changes that break the code still running on main
#      (dropped or renamed columns and tables, changed types, new required
#      columns); .squawk.toml leaves out the locking rules, which matter
#      for big tables, not ours. A drop that is safe (nothing on main reads
#      it) gets `-- squawk-ignore ban-drop-column` above it.
#   4. safeupdate: Supabase refuses an UPDATE or DELETE without a WHERE
#      clause in requests through its API (pg-safeupdate), also inside the
#      functions they call, and no local Postgres has it; so every function
#      in public must give each UPDATE and DELETE a WHERE (`where id` for
#      the one-row tables, `where true` when every row is meant).
#
# Uses the usual libpq variables, like db_test.sh. Needs the
# postgresql-16-plpgsql-check package and squawk (pip install squawk-cli).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
db=${DB_TEST_NAME:-mdt_test}
# Supabase's splinter at a fixed commit (Apache 2.0).
splinter_commit=fccca4b1c4d8b48b8ccd69bd6b30e84adcb92975
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -d "$db" "$@"; }
indent() { sed "s/^/     /"; }
failed=0

# 1. plpgsql_check, in its own schema (so splinter doesn't flag it).
psql_db -c "set client_min_messages to warning" -c "create schema if not exists lint" \
        -c "create extension if not exists plpgsql_check schema lint"
problems=$(psql_db -At -F ' | ' <<'SQL'
select f.oid::regprocedure, c.level, c.message, 'line ' || c.lineno
from pg_catalog.pg_proc f
join pg_catalog.pg_namespace n on n.oid = f.pronamespace
join pg_catalog.pg_language l on l.oid = f.prolang
left join lateral (
  select t.tgrelid from pg_catalog.pg_trigger t
  where t.tgfoid = f.oid and not t.tgisinternal limit 1
) trg on true
cross join lateral lint.plpgsql_check_function_tb(
  f.oid, coalesce(trg.tgrelid, 0), fatal_errors => false, extra_warnings => true
) c
where n.nspname = 'public' and l.lanname = 'plpgsql'
  and (f.prorettype <> 'trigger'::regtype or trg.tgrelid is not null)
order by 1;
SQL
)
if [ -n "$problems" ]; then
  echo "FAIL plpgsql_check:"; indent <<<"$problems"; failed=1
else
  echo "ok   plpgsql_check ($(psql_db -At -c "select count(*) from pg_proc f join pg_language l on l.oid = f.prolang where f.pronamespace = 'public'::regnamespace and l.lanname = 'plpgsql'") functions)"
fi

# 2. splinter. unused_index and table_bloat depend on real traffic, which a
# test database has none of.
splinter=$(mktemp)
curl -fsSL -o "$splinter" "https://raw.githubusercontent.com/supabase/splinter/$splinter_commit/splinter.sql"
allowed=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$root/supabase/lint_allow.txt")
# CSV, since descriptions hold newlines; printed as key, level, detail.
findings=$( { echo 'begin;'; cat "$splinter"; echo '; rollback;'; } \
  | psql -X -q -v ON_ERROR_STOP=1 -d "$db" --csv -f - \
  | python3 -I -c '
import csv, sys
for row in csv.DictReader(line for line in sys.stdin if line.strip()):
    if row.get("cache_key") and row["name"] not in ("unused_index", "table_bloat"):
        print(row["cache_key"], row["level"], " ".join(row["detail"].split()), sep="\t")
')
rm -f "$splinter"
new=$(echo "$findings" | sed '/^$/d' | while IFS=$'\t' read -r key level detail; do
  grep -qxF "$key" <<<"$allowed" || printf '%s %s (%s)\n' "$level" "$detail" "$key"
done)
if [ -n "$new" ]; then
  echo "FAIL splinter (fix it, or add the key to supabase/lint_allow.txt with the reason):"
  indent <<<"$new"; failed=1
else
  echo "ok   splinter"
fi
# Allow-list entries that no longer match anything: drop them.
while read -r key; do
  [ -n "$key" ] || continue
  if ! cut -f1 <<<"$findings" | grep -qxF "$key"; then
    echo "FAIL supabase/lint_allow.txt: $key no longer applies, remove it"; failed=1
  fi
done <<<"$allowed"

# 3. squawk on the migrations not on main yet.
base=$(git -C "$root" merge-base origin/main HEAD 2>/dev/null || true)
if [ -n "$base" ]; then
  mapfile -t added < <(git -C "$root" diff --name-only --diff-filter=A "$base" HEAD -- supabase/migrations/)
  if [ ${#added[@]} -gt 0 ]; then
    if (cd "$root" && squawk --config .squawk.toml "${added[@]}"); then
      echo "ok   squawk (${#added[@]} new migrations)"
    else
      echo "FAIL squawk"; failed=1
    fi
  else
    echo "ok   squawk (no new migrations)"
  fi
fi
# 4. safeupdate: an UPDATE or DELETE without WHERE in a function body
# (comments and string literals left out; ON CONFLICT's DO UPDATE is not
# its own statement).
unsafe=$(psql_db --csv -c "select f.oid::regprocedure as name, f.prosrc as body
  from pg_catalog.pg_proc f where f.pronamespace = 'public'::regnamespace" \
  | python3 -I "$root/tool/safe_updates.py")
if [ -n "$unsafe" ]; then
  echo "FAIL safeupdate (add a WHERE; Supabase's API refuses these):"
  indent <<<"$unsafe"; failed=1
else
  echo "ok   safeupdate"
fi
exit $failed
