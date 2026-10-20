#!/usr/bin/env bash
# Checks the migrations a change adds, between two commits:
#   tool/check_migrations.sh BASE HEAD
#
# A migration already on main may have been applied to the live database,
# and `supabase db push` never runs a file again, so:
#   - an existing migration must not be changed, renamed or deleted (add a
#     new migration instead);
#   - a new one must be named <14-digit version>_<name>.sql and sort after
#     every migration in BASE (db push refuses older versions).
# Prints the new migrations and, on GitHub Actions, writes `count=N` to
# $GITHUB_OUTPUT (0: nothing to apply). Exits 1 on any problem.
set -euo pipefail

base=${1:?usage: check_migrations.sh BASE HEAD}
head=${2:?usage: check_migrations.sh BASE HEAD}
dir=supabase/migrations

latest=$(git ls-tree --name-only "$base" "$dir/" | sed -n "s|^$dir/\([0-9]\{14\}\)_.*\.sql$|\1|p" \
  | sort | tail -n 1)

problems=0
added=()
while IFS=$'\t' read -r status path rest; do
  [ -n "$status" ] || continue
  case "$status" in
    A)
      name=$(basename "$path")
      if [[ ! "$name" =~ ^([0-9]{14})_[a-z0-9_]+\.sql$ ]]; then
        echo "::error file=$path::Name it <14-digit version>_<name>.sql (make db-new NAME=...)"
        problems=1
      elif [[ -n "$latest" && ! "${BASH_REMATCH[1]}" > "$latest" ]]; then
        echo "::error file=$path::Version ${BASH_REMATCH[1]} is not after the latest on main ($latest); create it again with make db-new"
        problems=1
      else
        added+=("$path")
      fi
      ;;
    *)
      # M (changed), D (deleted), R/C (renamed/copied: the old path is $path).
      echo "::error file=${rest:-$path}::A migration already on main was changed, renamed or deleted ($status $path${rest:+ -> $rest}); add a new migration instead"
      problems=1
      ;;
  esac
done < <(git diff --name-status --no-renames "$base" "$head" -- "$dir/")

if [ ${#added[@]} -eq 0 ]; then
  echo "No new migrations."
else
  echo "New migrations:"
  printf '  %s\n' "${added[@]}"
fi
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "count=${#added[@]}" >> "$GITHUB_OUTPUT"
fi
exit $problems
