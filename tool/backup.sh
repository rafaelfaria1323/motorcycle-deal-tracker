#!/usr/bin/env bash
# Dumps the database for the weekly backup (.github/workflows/backup.yml):
#
#   tool/backup.sh DB_URL OUT_DIR
#
# OUT_DIR gets:
#   public.dump    pg_dump custom format of the schema public (tables and
#                  data: listings, price history, alerts, accounts' lists...)
#   accounts.dump  the data of auth.users and auth.identities (the accounts
#                  the public tables point to; Supabase's own schema comes
#                  with any new project)
#   counts.tsv     each public table's rows when dumped (for the restore check)
#   about.txt      when, and the server's version
# The Vault, pg_cron's jobs and Supabase's other schemas are not dumped: the
# migrations make the jobs again, and the secrets are typed again
# (docs/hosting.md). The dumps hold sellers' data: the workflow encrypts
# them before they leave the runner. Restored by tool/restore_backup.sh.
set -euo pipefail

url=${1:?usage: backup.sh DB_URL OUT_DIR}
out=${2:?usage: backup.sh DB_URL OUT_DIR}
mkdir -p "$out"
psql_db() { psql "$url" -X -q -v ON_ERROR_STOP=1 "$@"; }

pg_dump "$url" --format=custom --schema=public --no-owner --no-privileges \
  --file="$out/public.dump"
pg_dump "$url" --format=custom --data-only \
  --table=auth.users --table=auth.identities --file="$out/accounts.dump"

# Exact counts, right after the dumps (a collection writing meanwhile can
# move them a little: the check only warns about a difference).
tables=$(psql_db -At -c "select tablename from pg_tables where schemaname = 'public' order by 1")
: > "$out/counts.tsv"
for t in $tables; do
  n=$(psql_db -At -c "select count(*) from public.\"$t\"")
  printf '%s\t%s\n' "$t" "$n" >> "$out/counts.tsv"
done

{
  echo "made_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "server_version=$(psql_db -At -c 'show server_version')"
  echo "pg_dump=$(pg_dump --version)"
} > "$out/about.txt"

# Both archives must be readable before they count as a backup.
pg_restore --list "$out/public.dump" >/dev/null
pg_restore --list "$out/accounts.dump" >/dev/null
echo "Dumped $(wc -l < "$out/counts.tsv") tables:"
ls -l "$out"
