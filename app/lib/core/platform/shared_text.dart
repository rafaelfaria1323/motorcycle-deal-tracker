import 'shared_text_stub.dart'
    if (dart.library.js_interop) 'shared_text_web.dart'
    as impl;

/// Text shared to the Android app from another app's Share menu (N.103):
/// [open] gets the text the app was started with, then each one shared
/// while it runs. The browser is never a share target (an iPhone
/// home-screen app can't be one): nothing comes.
Future<void> listenToSharedText(void Function(String text) open) =>
    impl.listenToSharedText(open);
