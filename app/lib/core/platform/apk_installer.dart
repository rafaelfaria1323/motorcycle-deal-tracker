import 'package:flutter/services.dart';

/// The Android app's own updater (the plugin in packages/apk_installer).
/// Only in the Android app: elsewhere the calls fail.
abstract final class ApkInstaller {
  static const _channel = MethodChannel('deal_tracker/apk_installer');

  /// The text at [url] (the release's version file).
  static Future<String?> readText(String url) =>
      _channel.invokeMethod<String>('readText', url);

  /// Downloads the APK at [url] and opens Android's installer with it; the
  /// person confirms there.
  static Future<void> install(String url) =>
      _channel.invokeMethod<void>('install', url);
}
