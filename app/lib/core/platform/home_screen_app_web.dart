import 'dart:js_interop';

// `navigator.standalone` exists only in Safari on iPhone/iPad and is true in
// a home-screen app.
@JS('navigator.standalone')
external JSBoolean? get _standalone;

// In CSS pixels, in portrait. iPhones with a home bar are at least 812 tall
// (iPhone X and later); those with a Home button are shorter.
@JS('screen.height')
external JSNumber get _screenHeight;

@JS('screen.width')
external JSNumber get _screenWidth;

bool get isIphoneHomeScreenAppWithHomeBar {
  final standalone = _standalone?.toDart ?? false;
  if (!standalone) return false;
  final longSide = _screenHeight.toDartDouble > _screenWidth.toDartDouble
      ? _screenHeight.toDartDouble
      : _screenWidth.toDartDouble;
  return longSide >= 812;
}
