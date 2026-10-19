import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/catalog_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/shared_listing_text.dart';

CatalogModel model(String brand, String name) => CatalogModel(
  id: name,
  brand: brand,
  model: name,
  minYear: 2018,
  isTracked: true,
);

final catalog = [
  model('Yamaha', 'MT-07'),
  model('Yamaha', 'Tracer 7'),
  model('Yamaha', 'R1'),
  model('Yamaha', 'R7'),
  model('Honda', 'CB650R'),
  model('Honda', 'CBR650R'),
];

void main() {
  group('sharedSource', () {
    test('a Marketplace item keeps only its number', () {
      final s = sharedSource(
        'https://m.facebook.com/marketplace/item/1234567890/?ref=share&mibextid=x',
      )!;
      expect(s.source, 'facebook');
      expect(s.sourceListingId, 'facebook.com/marketplace/item/1234567890');
      expect(s.url, 'https://www.facebook.com/marketplace/item/1234567890/');
      expect(
        sharedSource('https://www.facebook.com/marketplace/item/1234567890')!
            .sourceListingId,
        s.sourceListingId,
      );
    });

    test('a CustoJusto ad is its number', () {
      final s = sharedSource(
        'https://www.custojusto.pt/lisboa/veiculos/motos/yamaha-mt-07-41234567?ref=x',
      )!;
      expect(s.source, 'custojusto');
      expect(s.sourceListingId, 'custojusto.pt/41234567');
      expect(
        s.url,
        'https://www.custojusto.pt/lisboa/veiculos/motos/yamaha-mt-07-41234567',
      );
    });

    test('any other site is its address without the query', () {
      final s = sharedSource('http://Stand.Example.pt/motos/mt07/?utm=1')!;
      expect(s.source, 'other');
      expect(s.sourceListingId, 'stand.example.pt/motos/mt07');
      expect(s.url, 'https://stand.example.pt/motos/mt07/');
    });

    test('not an address', () {
      expect(sharedSource('MT-07 a bom preço'), isNull);
      expect(sharedSource('ftp://x.pt/a'), isNull);
      expect(sharedSource(''), isNull);
    });
  });

  group('guessModel', () {
    String? guess(String text) => guessModel(text, catalog)?.model;

    test('spellings sellers use', () {
      expect(guess('Yamaha MT07 35kw'), 'MT-07');
      expect(guess('Yamaha MT 07 de 2021'), 'MT-07');
      expect(guess('Honda CB 650 R Neo Sports Café'), 'CB650R');
      expect(guess('Honda CBR650R'), 'CBR650R');
      expect(guess('Yamaha YZF-R7'), 'R7');
      expect(guess('Yamaha Tracer 7 GT'), 'Tracer 7');
    });

    test('no guess when nothing or two models fit', () {
      expect(guess('Yamaha YZF-R125'), isNull);
      expect(guess('Kawasaki Z650'), isNull);
      expect(guess('Troco R1 por R7'), isNull);
    });
  });

  test('parsePrice reads the euro formats sites use', () {
    expect(parsePrice('7 500 €'), 7500);
    expect(parsePrice('€7,500'), 7500);
    expect(parsePrice('Preço: 7.500€'), 7500);
    expect(parsePrice('6 990,00 €'), 6990);
    expect(parsePrice('6990 EUR'), 6990);
    expect(parsePrice('Yamaha MT-07 2021 · 7 500 €'), 7500);
    expect(parsePrice('Yamaha MT-07 2021'), isNull);
  });

  test('parseYear and parseMileage', () {
    final now = DateTime(2026, 10, 20);
    expect(parseYear('Yamaha MT-07 2021 A2', now: now), 2021);
    expect(parseYear('MT-07 com 35000 km', now: now), isNull);
    expect(parseYear('Modelo 2031', now: now), isNull);
    expect(parseMileage('Tem 12 000 km, revisões feitas'), 12000);
    expect(parseMileage('8.500 kms'), 8500);
    expect(parseMileage('8500km'), 8500);
    expect(parseMileage('Sem quilómetros indicados'), isNull);
  });

  group('sharedListingProblems', () {
    Map<String, String> problems({
      String link = 'https://www.facebook.com/marketplace/item/1/',
      String? modelId = 'MT-07',
      String price = '6 900',
      String year = '',
      String mileage = '',
    }) => sharedListingProblems(
      link: link,
      modelId: modelId,
      price: price,
      year: year,
      mileage: mileage,
      now: DateTime(2026, 10, 20),
    );

    test('a complete form has none', () {
      expect(problems(), isEmpty);
      expect(problems(year: '2021', mileage: '12.000'), isEmpty);
    });

    test('each field says what is wrong', () {
      expect(problems(link: 'olá').keys, ['link']);
      expect(
        problems(link: 'https://www.olx.pt/d/anuncio/x.html')['link'],
        contains('recolhidos automaticamente'),
      );
      expect(problems(modelId: null).keys, ['model']);
      expect(problems(price: '').keys, ['price']);
      expect(problems(year: '1975').keys, ['year']);
      expect(problems(mileage: '900000').keys, ['mileage']);
    });
  });

  test('parseAmount reads the form price', () {
    expect(parseAmount('6 990'), 6990);
    expect(parseAmount('6.990 €'), 6990);
    expect(parseAmount('6990,50'), 6990.5);
    expect(parseAmount('abc'), isNull);
  });

  test('the share button fills the form from what the page shows', () {
    final prefill = sharedPrefill({
      'u': 'https://www.facebook.com/marketplace/item/123/?ref=share',
      't': 'Yamaha MT-07 2021',
      'p': '6 900 €',
      'd': 'Mota impecável, 12 000 km, revisões na marca.',
      'l': 'Lisboa, Portugal',
      'i': 'https://scontent.xx.fbcdn.net/x.jpg',
    }, now: DateTime(2026, 10, 20));

    expect(
      prefill.link,
      'https://www.facebook.com/marketplace/item/123/?ref=share',
    );
    expect(prefill.title, 'Yamaha MT-07 2021');
    expect(prefill.price, 6900);
    expect(prefill.year, 2021);
    expect(prefill.mileage, 12000);
    expect(prefill.location, 'Lisboa');
    expect(prefill.image, 'https://scontent.xx.fbcdn.net/x.jpg');
  });

  test('an empty share leaves the form empty', () {
    final prefill = sharedPrefill(const {});
    expect(prefill.link, isEmpty);
    expect(prefill.price, isNull);
    expect(prefill.image, isNull);
  });

  test('save errors', () {
    expect(sharedSaveErrorText('42501'), contains('sessão'));
    expect(sharedSaveErrorText('22023'), contains('Verifique'));
    expect(sharedSaveErrorText(null), contains('Tente novamente'));
  });
}
