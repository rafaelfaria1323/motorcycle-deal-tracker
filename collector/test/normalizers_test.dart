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

    test('strips every trailing slash, down to the bare host', () {
      expect(canonicalListingId('https://example.com//'), 'example.com');
      expect(canonicalListingId('https://example.com/a/'), 'example.com/a');
      expect(canonicalListingId('https://example.com/ab/'), 'example.com/ab');
    });

    test('a ref parameter is tracking, not part of the id', () {
      expect(
        canonicalListingId('https://example.com/ad?ref=home'),
        'example.com/ad',
      );
    });
  });

  group('cleanDescription', () {
    test('turns &quot; into a quote and an empty list item into nothing', () {
      expect(cleanDescription('a &quot;b&quot;'), 'a "b"');
      expect(cleanDescription('<li></li>'), isNull);
    });

    test('leaves numeric entities it cannot turn into a character as text', () {
      expect(cleanDescription('a &#99999999; b'), 'a &#99999999; b');
      expect(
        cleanDescription('&#99999999999999999999;'),
        '&#99999999999999999999;',
      );
      expect(cleanDescription('it&#39;s &#65;'), "it's A");
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
