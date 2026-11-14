import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/app/router/shared_text_open.dart';

void main() {
  group('sharedTextLocation', () {
    test("an ad shared from a site's app opens with its link alone", () {
      final location = sharedTextLocation(
        'Vê este anúncio no OLX: Kawasaki Z650 '
        'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html?utm_source=app',
      );
      final uri = Uri.parse(location);
      expect(uri.path, '/check-ad');
      expect(
        uri.queryParameters['link'],
        'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html',
      );
    });

    test('other text is carried as it is, so the form says it is no ad', () {
      final uri = Uri.parse(sharedTextLocation('  kawasaki z650 & co  '));
      expect(uri.path, '/check-ad');
      expect(uri.queryParameters['link'], 'kawasaki z650 & co');
    });

    test('a long text is cut', () {
      final uri = Uri.parse(sharedTextLocation('x' * 2000));
      expect(uri.queryParameters['link'], hasLength(500));
    });
  });
}
