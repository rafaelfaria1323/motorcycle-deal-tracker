/// Height of `#edge-tint-bottom` in `web/index.html`.
const safariStripHeight = 12.0;

const homeBarHeight = 24.0;

/// The extra bottom inset for [iosBottomInset]'s rules.
///
/// [standalone] is `navigator.standalone`: null outside Safari on
/// iPhone/iPad, true in a home-screen app. The screen size (CSS pixels) is
/// only read when needed, in the home-screen app: iPhones with a home bar
/// are at least 812 tall (iPhone X and later); those with a Home button are
/// shorter.
double bottomInsetFor({
  required bool? standalone,
  required double Function() screenHeight,
  required double Function() screenWidth,
}) {
  if (standalone == null) return 0; // not Safari on iPhone/iPad
  if (!standalone) return safariStripHeight;

  final height = screenHeight();
  final width = screenWidth();
  final longSide = height > width ? height : width;
  return longSide >= 812 ? homeBarHeight : 0;
}
