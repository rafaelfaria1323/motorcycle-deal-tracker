import 'home_screen_app_stub.dart'
    if (dart.library.js_interop) 'home_screen_app_web.dart'
    as impl;

/// Room for the iPhone's home bar under the tab bar. In the home-screen app
/// the page runs under the home bar, and Flutter on the web reports no
/// safe area for it, so the tab bar labels would sit beneath the bar.
const homeBarInset = 24.0;

/// True in the app added to the iPhone home screen ("Adicionar ao ecrã
/// principal") on an iPhone with a home bar (no Home button).
bool get isIphoneHomeScreenAppWithHomeBar =>
    impl.isIphoneHomeScreenAppWithHomeBar;
