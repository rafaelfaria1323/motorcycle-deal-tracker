import 'package:flutter/services.dart';

import 'share_file.dart';

const _channel = MethodChannel('deal_tracker/file_share');

/// The Android app: the in-repo plugin packages/file_share writes the file
/// to its cache and opens Android's share sheet with it.
Future<FileShareOutcome> shareFile({
  required Uint8List bytes,
  required String name,
  required String type,
  required String title,
}) async {
  try {
    final shared = await _channel.invokeMethod<bool>('share', {
      'bytes': bytes,
      'name': name,
      'type': type,
      'title': title,
    });
    return shared ?? false
        ? FileShareOutcome.shared
        : FileShareOutcome.unavailable;
  } on PlatformException {
    return FileShareOutcome.unavailable;
  } on MissingPluginException {
    // Not the Android app (tests, desktop).
    return FileShareOutcome.unavailable;
  }
}
