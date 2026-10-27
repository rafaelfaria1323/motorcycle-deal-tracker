#!/usr/bin/env bash
# The Android build's cache keys (deploy-web.yml, android-check.yml), as
# GitHub step outputs: the NDK this Flutter builds with (its version and
# where Gradle installs it; empty if Flutter's file changed shape, then the
# NDK is simply not cached) and a hash of the Flutter SDK's Android
# settings (Gradle plugin, SDK and NDK versions). Needs FLUTTER_ROOT and
# ANDROID_HOME (set by flutter-action and the runner).
set -euo pipefail

settings="$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
ndk=$(sed -n 's/.*val ndkVersion: String = "\(.*\)".*/\1/p' "$settings")
echo "ndk=$ndk"
echo "ndk_path=$ANDROID_HOME/ndk/$ndk"
echo "flutter=$(sha256sum "$settings" | cut -c1-16)"
