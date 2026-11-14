import 'dart:js_interop';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSString> parts, JSObject options);
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
}) async {
  try {
    final blob = _Blob(
      [text.toJS].toJS,
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
