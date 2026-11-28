import 'dart:js_interop';
import 'dart:typed_data';

import 'download_web.dart';
import 'share_file.dart';

@JS('File')
extension type _File._(JSObject _) implements JSObject {
  external factory _File(JSArray<JSAny> parts, String name, JSObject options);
}

/// `{title, files}` for `navigator.canShare` and `navigator.share`.
extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({String title, JSArray<_File> files});
}

@JS('navigator.canShare')
external JSFunction? get _canShareFunction;

@JS('navigator.canShare')
external bool _canShare(_ShareData data);

@JS('navigator.share')
external JSPromise<JSAny?> _share(_ShareData data);

/// The browser: the share sheet with the file where it can take files
/// (Safari, Chrome on Android and Windows), else a download.
Future<FileShareOutcome> shareFile({
  required Uint8List bytes,
  required String name,
  required String type,
  required String title,
}) async {
  _ShareData? data;
  try {
    if (_canShareFunction != null) {
      final file = _File(
        <JSAny>[bytes.toJS].toJS,
        name,
        {'type': type}.jsify()! as JSObject,
      );
      final candidate = _ShareData(title: title, files: [file].toJS);
      if (_canShare(candidate)) data = candidate;
    }
  } on Object {
    // No sharing of files here: the file is downloaded.
  }
  if (data != null) {
    try {
      await _share(data).toDart;
      return FileShareOutcome.shared;
    } on Object catch (e) {
      // Closing the sheet without choosing is an AbortError: nothing to
      // do. Anything else (no tap left to open it) downloads the file.
      if (e.toString().contains('AbortError')) return FileShareOutcome.shared;
    }
  }
  return await downloadBytes(name, bytes, type: type)
      ? FileShareOutcome.downloaded
      : FileShareOutcome.unavailable;
}
