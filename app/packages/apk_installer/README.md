# apk_installer

The Android app's own updater, a Flutter plugin used only by this app
(path dependency in `app/pubspec.yaml`). Two calls on the channel
`deal_tracker/apk_installer`, made by `lib/core/platform/apk_installer.dart`:

- `readText(url)`: a small text file (the release's `android.json`, which
  names the latest build);
- `install(url)`: downloads the APK into the app's cache and opens
  Android's installer with it. Android asks the person to confirm, and the
  first time to allow installs from this app; nothing installs silently.

Its manifest brings the `REQUEST_INSTALL_PACKAGES` permission and the file
provider that lets the installer read the downloaded file. Java only, so
it needs nothing but the Android Gradle plugin the app already has.
