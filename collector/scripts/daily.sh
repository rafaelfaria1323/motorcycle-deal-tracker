#!/usr/bin/env bash
# One scheduled collection: update the code, refresh the data, record how it
# went. Pass --now to skip the random start delay (for a manual run).
set -uo pipefail

REPO="${REPO:-$HOME/motorcycle-deal-tracker}"
ENV_FILE="${ENV_FILE:-$HOME/.config/motodeals/collector.env}"
LOG_DIR="${LOG_DIR:-$HOME/motodeals-logs}"

# Don't hit the site at the exact same minute every day.
if [ "${1:-}" != "--now" ]; then
  sleep $((RANDOM % 1200))
fi

mkdir -p "$LOG_DIR"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log="$LOG_DIR/$(date +%Y-%m-%d_%H%M).log"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a
export PATH="$HOME/dart-sdk/bin:$PATH"

cd "$REPO" || exit 1
{
  echo "== run started $started"
  git pull --ff-only &&
    (cd collector && dart pub get) &&
    make refresh ARGS=--full
} >"$log" 2>&1
code=$?
echo "== exit code $code" >>"$log"

(cd collector && dart run bin/report_run.dart "$code" "$started" "$log") >>"$log" 2>&1

# Keep a month of logs.
find "$LOG_DIR" -name '*.log' -mtime +30 -delete
exit "$code"