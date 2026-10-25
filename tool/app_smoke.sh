#!/usr/bin/env bash
# Runs the app's offline browser smoke test with its own ChromeDriver.
set -euo pipefail
cd "$(dirname "$0")/../app"

if ! command -v chromedriver >/dev/null; then
  echo "ChromeDriver is required on PATH (matching the installed Chrome)." >&2
  exit 127
fi

log=$(mktemp)
chromedriver --port=0 >"$log" 2>&1 &
driver_pid=$!
trap '
  kill "$driver_pid" 2>/dev/null || :
  wait "$driver_pid" 2>/dev/null || :
  rm -f "$log"
' EXIT

for _ in {1..50}; do
  if ! kill -0 "$driver_pid" 2>/dev/null; then
    cat "$log" >&2
    exit 1
  fi
  port=$(sed -nE 's/.*started successfully on port ([0-9]+).*/\1/p' "$log")
  if [[ -n "$port" ]] &&
      curl --fail --silent --max-time 1 "http://127.0.0.1:$port/status" >/dev/null; then
    flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/app_smoke_test.dart \
      --device-id=web-server --headless --no-web-resources-cdn \
      --browser-dimension=390x844 \
      --driver-port="$port"
    exit 0
  fi
  sleep 0.1
done

cat "$log" >&2
echo "ChromeDriver did not become ready." >&2
exit 1
