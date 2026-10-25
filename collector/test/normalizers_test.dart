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

    test('invalid numeric entities follow HTML5 replacement rules', () {
      expect(cleanDescription('a &#99999999; b'), 'a \uFFFD b');
      expect(cleanDescription('&#99999999999999999999;'), '\uFFFD');
      expect(cleanDescription('&#xFFFFFFFFFFFFFFFF;'), '\uFFFD');
      expect(cleanDescription('&#XFFFFFFFFFFFFFFFFFFFF;'), '\uFFFD');
      expect(cleanDescription('it&#39;s &#65;'), "it's A");
    });

    test('decodes named, decimal and hexadecimal entities exactly once', () {
      expect(
        cleanDescription('Revis&atilde;o &#231; &#xE3; &amp;nbsp; &nbsp; fim'),
        'Revisão ç ã &nbsp; fim',
      );
      expect(cleanDescription('&lt;b&gt;texto&lt;/b&gt;'), '<b>texto</b>');
    });

    test('keeps paragraphs, breaks, headings and list items', () {
      expect(
        cleanDescription(
          '<h2>Extras</h2><p>Mota <strong>estimada</strong><br>Garagem</p>'
          '<ul><li>Escape<li>Pneus novos<li></ul><div>Fim</div>',
        ),
        'Extras\nMota estimada\nGaragem\n- Escape\n- Pneus novos\nFim',
      );
    });

    test(
      'handles quoted tag attributes and ignores non-description content',
      () {
        expect(
          cleanDescription(
            '<p title="a > b">Texto</p><!-- comentário -->'
            '<script>acidente</script><style>.x { color: red; }</style>'
            '<p>km < 8000</p>',
          ),
          'Texto\nkm < 8000',
        );
      },
    );

    test('still removes dealer boilerplate after decoding entities', () {
      expect(
        cleanDescription(
          '<p>Mota estimada.</p><p>An&uacute;ncio introduzido por rotina '
          'inform&aacute;tica.</p><p>Todos os dados carecem de '
          'confirmação presencial.</p><p>Revisão feita.</p>',
        ),
        'Mota estimada.\nRevisão feita.',
      );
      expect(cleanDescription(null), isNull);
      expect(cleanDescription(42), isNull);
      expect(cleanDescription(' <br><!-- vazio -->'), isNull);
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
