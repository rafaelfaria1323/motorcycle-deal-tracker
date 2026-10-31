#!/usr/bin/env bash
# Builds the Android app's release APK into
# app/build/app/outputs/flutter-apk/app-release.apk, signed with the
# template's throwaway debug key (deploy-web.yml signs it again with ours).
# Used by deploy-web.yml and android-check.yml; needs Flutter and Java.
# Both keep ~/.gradle and the NDK between runs (tool/android_cache_keys.sh).
#
# app/android is not in the repository: it is made afresh from this
# Flutter's template (so it always matches it), then fitted by
# tool/android_manifest.py (internet permission, name) and given the app's
# icon. The package name never changes (Android treats another one as
# another app). The build number is the version code, so each build
# installs over the one before. Phones are 64-bit ARM (a smaller APK than
# one for every processor).
#
# Usage: tool/android_build.sh <build number>
# The app's settings come from the environment, empty when unset:
# SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, APK_URL, WEB_URL; and
# FIREBASE_ANDROID_CONFIG (google-services.json) for its notifications,
# written as resource strings by tool/firebase_values.py (without it the
# app has none).
set -euo pipefail

build="${1:?usage: tool/android_build.sh <build number>}"
cd "$(dirname "$0")/../app"

flutter create --platforms=android --org io.github.rafaelfaria1323 \
  --project-name motorcycle_deal_tracker .
python3 ../tool/android_manifest.py android/app/src/main/AndroidManifest.xml
# Gradle's build cache: tasks whose inputs didn't change (the plugins' Java
# and Kotlin, R8) come from ~/.gradle, which the workflows keep between runs.
echo 'org.gradle.caching=true' >> android/gradle.properties
if [[ -n "${FIREBASE_ANDROID_CONFIG:-}" ]]; then
  mkdir -p android/app/src/main/res/values
  printf '%s' "$FIREBASE_ANDROID_CONFIG" |
    python3 ../tool/firebase_values.py android/app/src/main/res/values/firebase.xml
else
  echo "FIREBASE_ANDROID_CONFIG not set: the app is built without notifications" >&2
fi
flutter pub get --enforce-lockfile
dart run flutter_launcher_icons

flutter build apk --release --target-platform android-arm64 \
  --build-name="1.0.$build" --build-number="$build" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=APK_URL="${APK_URL:-}" \
  --dart-define=APP_BUILD="$build" \
  --dart-define=WEB_URL="${WEB_URL:-}"

# No Gradle daemon left writing to ~/.gradle while the workflow saves it.
(cd android && ./gradlew --stop) || true
