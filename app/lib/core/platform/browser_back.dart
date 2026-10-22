import 'browser_back_stub.dart'
    if (dart.library.js_interop) 'browser_back_web.dart'
    as impl;

/// In the browser, steps back in its history when the entry before this
/// one is still the app's, and returns true; otherwise (the first page
/// opened, or not a browser) does nothing and returns false.
///
/// An in-app back arrow must do this on the web: popping with go_router
/// reports the screen beneath as a new history entry, so the browser's
/// (and the phone's) back gesture would then open the page just closed.
bool browserBack() => impl.browserBack();
