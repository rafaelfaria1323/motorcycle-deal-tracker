import 'dart:js_interop';

// `navigator.standalone` exists only in Safari on iPhone/iPad (null
// elsewhere) and is true in a home-screen app.
@JS('navigator.standalone')
external JSBoolean? get _standalone;

// In CSS pixels. iPhones with a home bar are at least 812 tall (iPhone X
// and later); those with a Home button are shorter.
@JS('screen.height')
external JSNumber get _screenHeight;

@JS('screen.width')
external JSNumber get _screenWidth;

/// Height of `#edge-tint-bottom` in `web/index.html`.
const _safariStripHeight = 12.0;

const _homeBarHeight = 24.0;

double get iosBottomInset {
  final standalone = _standalone;
  if (standalone == null) return 0; // not Safari on iPhone/iPad
  if (!standalone.toDart) return _safariStripHeight;

  final height = _screenHeight.toDartDouble;
  final width = _screenWidth.toDartDouble;
  final longSide = height > width ? height : width;
  return longSide >= 812 ? _homeBarHeight : 0;
}
