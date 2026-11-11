import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/open_ad.dart';

void main() {
  final ad = Uri.parse('https://www.olx.pt/d/anuncio/mt-07-IDabc.html');

  test("the iPhone's home-screen app sends the ad to Safari", () {
    final target = adLaunch(ad, iosHomeScreenApp: true);
    expect(
      target.address.toString(),
      'x-safari-https://www.olx.pt/d/anuncio/mt-07-IDabc.html',
    );
    expect(target.window, '_top');
  });

  test('elsewhere the ad opens as it is', () {
    expect(adLaunch(ad, iosHomeScreenApp: false), (address: ad, window: null));
  });

  test('only web addresses are rewritten', () {
    final mail = Uri.parse('mailto:a@b.pt');
    expect(adLaunch(mail, iosHomeScreenApp: true), (
      address: mail,
      window: null,
    ));
  });
}
