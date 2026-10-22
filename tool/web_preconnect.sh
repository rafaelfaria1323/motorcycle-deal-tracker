#!/usr/bin/env bash
# Puts the database's address into the built index.html as a preconnect,
# so the browser opens that connection while the app is still
# downloading. The address comes from the build's secret, not the
# repository, so app/web/index.html holds only a marker.
#
#   tool/web_preconnect.sh app/build/web/index.html "$SUPABASE_URL"
set -euo pipefail

file=$1
url=$2
marker='<!-- database-preconnect -->'
if ! grep -qF "$marker" "$file"; then
  echo "No '$marker' in $file" >&2
  exit 1
fi
html=$(<"$file")
# crossorigin: the app's requests to the database are CORS requests.
printf '%s\n' "${html/"$marker"/<link rel=\"preconnect\" href=\"$url\" crossorigin>}" >"$file"
