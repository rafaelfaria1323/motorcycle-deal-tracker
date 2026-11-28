import 'dart:typed_data';

import 'share_file_stub.dart'
    if (dart.library.js_interop) 'share_file_web.dart'
    as impl;

/// What happened to a [shareFile].
enum FileShareOutcome {
  /// The share sheet opened with the file (and was used or closed).
  shared,

  /// The browser can't share files (most desktops): it was downloaded.
  downloaded,

  /// Neither: the caller shares something else (the report as text).
  unavailable,
}

/// Opens the device's share sheet with the file [name] of [type] (the
/// ad's report as a PDF, N.127): in the Android app through the in-repo
/// plugin packages/file_share, in the browser through `navigator.share`
/// where it takes files, else the file is downloaded. Call it straight
/// from a tap with the bytes ready: Safari opens the sheet only then.
Future<FileShareOutcome> shareFile({
  required Uint8List bytes,
  required String name,
  required String type,
  required String title,
}) => impl.shareFile(bytes: bytes, name: name, type: type, title: title);
