import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/ad_link.dart';

void main() {
  group('adLinkOf', () {
    test('an OLX ad, without its query or fragment', () {
      expect(
        adLinkOf(
          'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html?reason=x',
        ),
        'https://www.olx.pt/d/anuncio/kawasaki-z650-IDHk3aB.html',
      );
      expect(
        adLinkOf('https://m.olx.pt/d/pt/anuncio/z650-IDHk3aB.html#fotos'),
        'https://m.olx.pt/d/pt/anuncio/z650-IDHk3aB.html',
      );
    });

    test('a Standvirtual ad, also inside a share text', () {
      expect(
        adLinkOf(
          'Vê este anúncio: Kawasaki Z 650 '
          'https://www.standvirtual.com/motos/anuncio/kawasaki-z-650-ID8Q1m16.html',
        ),
        'https://www.standvirtual.com/motos/anuncio/kawasaki-z-650-ID8Q1m16.html',
      );
    });

    test('anything else is no ad', () {
      for (final text in [
        '',
        'kawasaki z650',
        'https://www.standvirtual.com/carros/anuncio/x-ID8Q1m16.html',
        'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/',
        'https://evil.example/olx.pt/d/anuncio/x-ID1.html',
        'https://www.olx.pt.evil.example/d/anuncio/x-ID1.html',
        'https://www.custojusto.pt/x-ID1.html',
      ]) {
        expect(adLinkOf(text), isNull, reason: text);
      }
    });
  });
}
