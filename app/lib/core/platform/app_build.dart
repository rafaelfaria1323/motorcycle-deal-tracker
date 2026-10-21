import 'package:flutter/foundation.dart';

/// What the deploy passes to the build (`--dart-define`); empty when run
/// by hand.
abstract final class AppBuild {
  /// The latest Android app (a GitHub release asset); empty: no download
  /// is offered.
  static const apkUrl = String.fromEnvironment('APK_URL');

  /// This build's number (the deploy's run), shown by the Android app.
  static const number = String.fromEnvironment('APP_BUILD');

  /// The web app's address, for the links the Android app shares.
  static const webUrl = String.fromEnvironment('WEB_URL');
}

/// Where the web app lives, for links to share: the page's own address in
/// the browser; in the Android app, the address the build was given
/// (`Uri.base` is a file there, which has no origin).
String get webOrigin => kIsWeb ? Uri.base.origin : AppBuild.webUrl;
