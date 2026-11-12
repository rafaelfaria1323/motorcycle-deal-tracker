import 'dart:js_interop';

import '../calendar/calendar_event.dart';

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

/// The browser: the event as an .ics file, downloaded; the phone's or the
/// computer's calendar opens it.
Future<bool> addToCalendar(CalendarEvent event) async {
  try {
    final blob = _Blob(
      [icsText(event, stamp: DateTime.now()).toJS].toJS,
      {'type': 'text/calendar;charset=utf-8'}.jsify()! as JSObject,
    );
    final url = _createObjectUrl(blob);
    _createElement('a')
      ..href = url
      ..download = 'visita.ics'
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
