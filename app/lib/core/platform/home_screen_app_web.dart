import 'dart:js_interop';

import 'ios_bottom_inset.dart';

// `navigator.standalone` exists only in Safari on iPhone/iPad (null
// elsewhere) and is true in a home-screen app.
@JS('navigator.standalone')
external JSBoolean? get _standalone;

@JS('screen.height')
external JSNumber get _screenHeight;

@JS('screen.width')
external JSNumber get _screenWidth;

double get iosBottomInset => bottomInsetFor(
  standalone: _standalone?.toDart,
  screenHeight: () => _screenHeight.toDartDouble,
  screenWidth: () => _screenWidth.toDartDouble,
);
