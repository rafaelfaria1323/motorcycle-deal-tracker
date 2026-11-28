import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, JSObject options);
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document.createElement')
external _Anchor _createElement(String tag);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

/// The browser: [text] as a file, downloaded through a link to a Blob.
Future<bool> downloadText(
  String name,
  String text, {
  required String type,
}) async => _download(name, text.toJS, type: type);

/// The browser: [bytes] as a file (the ad's report PDF, N.127).
Future<bool> downloadBytes(
  String name,
  Uint8List bytes, {
  required String type,
}) async => _download(name, bytes.toJS, type: type);

bool _download(String name, JSAny content, {required String type}) {
  try {
    final blob = _Blob(
      <JSAny>[content].toJS,
      {'type': type}.jsify()! as JSObject,
    );
    final url = _createObjectUrl(blob);
    _createElement('a')
      ..href = url
      ..download = name
      ..click();
    // Let the download start before the address goes.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => _revokeObjectUrl(url),
    );
    return true;
  } on Object {
    return false;
  }
}
