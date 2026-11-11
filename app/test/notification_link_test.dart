import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/notification_link.dart';

void main() {
  test('the web app address of a page opens that page', () {
    expect(notificationLink('/#/deals/42'), (
      location: '/deals/42',
      external: null,
    ));
    expect(notificationLink('#/summary'), (
      location: '/summary',
      external: null,
    ));
    expect(notificationLink('/collection-status'), (
      location: '/collection-status',
      external: null,
    ));
  });

  test("an ad's own address opens outside the app", () {
    expect(notificationLink('https://www.olx.pt/d/anuncio/x.html'), (
      location: null,
      external: Uri.parse('https://www.olx.pt/d/anuncio/x.html'),
    ));
  });

  test('anything else is ignored', () {
    expect(notificationLink(''), isNull);
    expect(notificationLink('javascript:alert(1)'), isNull);
    expect(notificationLink('deals/1'), isNull);
  });

  test('a link to the web app opens its page in the Android app', () {
    expect(appLinkLocation(Uri.parse('/#/deals/42')), '/deals/42');
    expect(appLinkLocation(Uri.parse('#/summary')), '/summary');
    expect(
      appLinkLocation(Uri.parse('https://example.pages.dev/#/deals/42')),
      '/deals/42',
    );
    expect(appLinkLocation(Uri.parse('/deals/42')), isNull);
    expect(appLinkLocation(Uri.parse('/models#/deals/42')), isNull);
    expect(appLinkLocation(Uri.parse('/#access_token=x')), isNull);
  });
}
