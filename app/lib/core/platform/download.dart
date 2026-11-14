import 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart'
    as impl;

/// Saves [text] as the file [name] of [type] (16.11's CSV): the browser
/// downloads it. False where it can't (the Android app, where the caller
/// copies the text instead).
Future<bool> downloadText(String name, String text, {required String type}) =>
    impl.downloadText(name, text, type: type);
