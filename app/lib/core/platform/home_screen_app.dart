import 'home_screen_app_stub.dart'
    if (dart.library.js_interop) 'home_screen_app_web.dart'
    as impl;

/// Extra bottom safe area on iPhone/iPad, which Flutter on the web doesn't
/// report:
/// - in Safari, 12px for the strip `web/index.html` puts at the bottom edge
///   (Safari 26 tints its toolbar from it), so it sits under the tab bar
///   labels instead of over them;
/// - in the home-screen app on an iPhone with a home bar, 24px so the
///   labels stay above the home bar (there is no strip there);
/// - 0 elsewhere.
double get iosBottomInset => impl.iosBottomInset;
