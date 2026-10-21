#!/bin/bash
# Claude Code cloud sessions: what `make collector-check`, `make tool-check`
# and `make db-test` need. Flutter is deliberately NOT installed (the app is
# checked by CI's `flutter analyze`/`flutter test`); app logic is tested
# with plain Dart on copies of the files.
#   - Dart SDK (latest stable) in ~/.cache/dart-sdk, on PATH
#   - collector dependencies (the lockfile is never changed)
#   - local Postgres running, with a superuser for the session's user
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

dart_dir="$HOME/.cache/dart-sdk"
if [ ! -x "$dart_dir/bin/dart" ]; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/dart.zip" \
    https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip
  unzip -q "$tmp/dart.zip" -d "$tmp"
  mkdir -p "$(dirname "$dart_dir")"
  rm -rf "$dart_dir"
  mv "$tmp/dart-sdk" "$dart_dir"
  rm -rf "$tmp"
fi
export PATH="$dart_dir/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$dart_dir/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
dart --version

# Never commit collector/pubspec.lock changes: resolve from the lockfile, and
# if this SDK can't, resolve anyway but put the committed lockfile back.
(
  cd collector
  if ! dart pub get --enforce-lockfile >/dev/null 2>&1; then
    dart pub get >/dev/null
    git checkout -- pubspec.lock
  fi
)

# make lint-scripts: actionlint is on the image, shellcheck may not be.
if ! command -v shellcheck >/dev/null 2>&1; then
  apt-get install -y -q shellcheck >/dev/null 2>&1 \
    || { apt-get update -q >/dev/null 2>&1 && apt-get install -y -q shellcheck >/dev/null 2>&1; } || true
fi

# make sql-lint: plpgsql_check for the local Postgres, and squawk.
if ! ls /usr/share/postgresql/*/extension/plpgsql_check.control >/dev/null 2>&1; then
  pkg="postgresql-$(psql --version | grep -oE '[0-9]+' | head -1)-plpgsql-check"
  apt-get install -y -q "$pkg" >/dev/null 2>&1 \
    || { apt-get update -q >/dev/null 2>&1 && apt-get install -y -q "$pkg" >/dev/null 2>&1; } || true
fi
command -v squawk >/dev/null 2>&1 || pip install -q squawk-cli==2.70.0 >/dev/null 2>&1 || true

# make db-test: Postgres through its socket, as a superuser named like us.
if command -v pg_ctlcluster >/dev/null 2>&1 || command -v service >/dev/null 2>&1; then
  service postgresql start >/dev/null 2>&1 || true
  me=$(id -un)
  if [ "$me" != postgres ]; then
    su postgres -c "psql -X -q -tAc \"select 1 from pg_roles where rolname = '$me'\"" 2>/dev/null \
      | grep -q 1 || su postgres -c "createuser -s $me" 2>/dev/null || true
  fi
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'export PGHOST=/var/run/postgresql PGDATABASE=postgres' >> "$CLAUDE_ENV_FILE"
  fi
fi
