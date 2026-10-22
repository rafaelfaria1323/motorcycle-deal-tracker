import 'first_page_stub.dart'
    if (dart.library.js_interop) 'first_page_web.dart'
    as impl;

/// The answer `index.html` got for the first listings and the model list
/// while the app downloaded (JSON text), taken once; null when there is
/// none (not a browser, a signed-in account, the request failed) or it
/// was already taken.
Future<String?> takeFirstPage() => impl.takeFirstPage();
