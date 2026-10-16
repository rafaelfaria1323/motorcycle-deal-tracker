import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  group('canonicalListingId', () {
    test('ignores scheme, www, trailing slash, fragment and tracking', () {
      expect(
        canonicalListingId(
          'https://WWW.Example.com/anuncio/r7-123/?utm_source=x&fbclid=y#fotos',
        ),
        'example.com/anuncio/r7-123',
      );
      expect(
        canonicalListingId('http://example.com/anuncio/r7-123'),
        'example.com/anuncio/r7-123',
      );
    });

    test('keeps meaningful query parameters, sorted', () {
      expect(
        canonicalListingId('https://example.com/ad?id=7&b=2&utm_medium=z'),
        'example.com/ad?b=2&id=7',
      );
    });
  });

  group('parseSellerType', () {
    test('understands English and Portuguese words', () {
      expect(parseSellerType('Particular'), SellerType.private);
      expect(parseSellerType(' Stand '), SellerType.dealer);
      expect(parseSellerType('banana'), isNull);
    });
  });
}
