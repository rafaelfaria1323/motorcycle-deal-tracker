#!/usr/bin/env bash
# Puts the database into the built index.html: its address as a
# preconnect, so the browser opens that connection while the app is still
# downloading, and, with the publishable key, as <meta name="database">,
# which index.html's script uses to ask for the first listings meanwhile.
# Both come from the build's secrets, not the repository, so
# app/web/index.html holds only a marker. The publishable key is public
# (the app carries it anyway; row-level security guards the data).
#
#   tool/web_preconnect.sh app/build/web/index.html "$SUPABASE_URL" "$SUPABASE_PUBLISHABLE_KEY"
set -euo pipefail

file=$1
url=$2
key=${3:-}
marker='<!-- database-preconnect -->'
if ! grep -qF "$marker" "$file"; then
  echo "No '$marker' in $file" >&2
  exit 1
fi
# crossorigin: the app's requests to the database are CORS requests.
tags="<link rel=\"preconnect\" href=\"$url\" crossorigin>"
if [ -n "$key" ]; then
  tags="$tags<meta name=\"database\" content=\"$url\" data-key=\"$key\">"
fi
html=$(<"$file")
printf '%s\n' "${html/"$marker"/$tags}" >"$file"
