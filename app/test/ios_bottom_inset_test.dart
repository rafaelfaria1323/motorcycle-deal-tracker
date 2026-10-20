import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/ios_bottom_inset.dart';

double _inset(bool? standalone, {double height = 0, double width = 0}) =>
    bottomInsetFor(
      standalone: standalone,
      screenHeight: () => height,
      screenWidth: () => width,
    );

void main() {
  test('no inset outside Safari on iPhone/iPad', () {
    expect(_inset(null, height: 900, width: 400), 0);
  });

  test('Safari gets the height of the bottom strip', () {
    expect(_inset(false, height: 900, width: 400), safariStripHeight);
  });

  test('home-screen app: home bar only on tall phones', () {
    expect(_inset(true, height: 852, width: 393), homeBarHeight);
    expect(_inset(true, height: 812, width: 375), homeBarHeight);
    expect(_inset(true, height: 667, width: 375), 0);
  });

  test('home-screen app: landscape uses the long side', () {
    expect(_inset(true, height: 393, width: 852), homeBarHeight);
    expect(_inset(true, height: 375, width: 667), 0);
  });

  test('the screen is not read unless the app is in the home screen', () {
    double fail() => throw StateError('read');
    expect(
      bottomInsetFor(standalone: false, screenHeight: fail, screenWidth: fail),
      safariStripHeight,
    );
  });
}
