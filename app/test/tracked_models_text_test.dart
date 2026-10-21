import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/catalog_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/tracked_models_text.dart';

const yamahaR =
    '${olxSearchPrefix}yamaha/?search%5Bfilter_enum_modelo%5D%5B0%5D=r';

CatalogModel model(
  String name, {
  bool tracked = true,
  bool collected = false,
  String? olx,
  String? standvirtual,
}) => CatalogModel(
  id: name,
  brand: 'Yamaha',
  model: name,
  minYear: 2023,
  isTracked: tracked,
  isCollected: collected,
  olxSearch: olx,
  standvirtualSearch: standvirtual,
);

void main() {
  test('the subtitle names the year and the sites searched', () {
    expect(
      modelSubtitle(
        model(
          'R7',
          olx: yamahaR,
          standvirtual: '${standvirtualSearchPrefix}yamaha/r/q-7',
        ),
      ),
      'Desde 2023 · OLX e Standvirtual',
    );
    expect(modelSubtitle(model('R7')), 'Desde 2023 · sem pesquisa');
  });

  test('tracked models that share a search count once', () {
    final counts = searchCounts([
      model('R7', olx: yamahaR),
      model('R1', olx: '$yamahaR&search%5Bfilter_float_year:from%5D=2021'),
      model('R9', olx: '${olxSearchPrefix}yamaha/', tracked: false),
      model('MT-07', standvirtual: '${standvirtualSearchPrefix}yamaha/mt-07'),
    ]);

    expect(counts.olx, 1);
    expect(counts.standvirtual, 1);
  });

  test('models only other accounts follow count too', () {
    final counts = searchCounts([
      model('R7', olx: yamahaR, tracked: false, collected: true),
      model('R9', olx: '${olxSearchPrefix}yamaha/', tracked: false),
    ]);

    expect(counts.olx, 1);
  });

  test('many OLX searches bring a warning', () {
    final few = budgetLines([model('R7', olx: yamahaR)]);
    final many = budgetLines([
      for (var i = 0; i < 6; i++) model('M$i', olx: '$yamahaR$i'),
    ]);

    expect(few, hasLength(1));
    expect(many, hasLength(2));
    expect(many.last, startsWith('Muitas pesquisas no OLX'));
  });

  group('the add-model form', () {
    Map<String, String> check({
      String brand = 'Kawasaki',
      String model = 'Z650',
      String year = '2023',
      String olx = '${olxSearchPrefix}kawasaki/',
      String standvirtual = '',
    }) => newModelProblems(
      brand: brand,
      model: model,
      year: year,
      olxSearch: olx,
      standvirtualSearch: standvirtual,
      currentYear: 2026,
    );

    test('a complete model is fine', () {
      expect(check(), isEmpty);
    });

    test('names each problem by field', () {
      expect(check(brand: ' ', model: '').keys, ['brand', 'model']);
      expect(check(year: '2030').keys, ['year']);
      expect(check(olx: '').keys, ['olx']);
      expect(check(olx: 'https://www.olx.pt/imoveis/').keys, ['olx']);
      expect(check(standvirtual: 'https://example.com/').keys, [
        'standvirtual',
      ]);
    });

    test('a Standvirtual search alone is enough', () {
      expect(
        check(olx: '', standvirtual: '${standvirtualSearchPrefix}kawasaki'),
        isEmpty,
      );
    });
  });

  test('other names are split on commas', () {
    expect(parseAliases(' Z 650, Z-650 ,, '), ['Z 650', 'Z-650']);
  });

  test('the new-bike price line says when it was checked', () {
    final priced = model('R7').withNewPrice(10640, DateTime(2026, 10, 13));

    expect(
      newPriceSubtitle(priced),
      'Preço de uma nova: ${Formatters.price(10640)} '
      '(verificado em 13/10/2026)',
    );
    expect(newPriceSubtitle(model('R9')), 'Sem preço de uma nova');
  });

  test('prices are read the way they are written in Portugal', () {
    expect(parseNewPrice('8250').price, 8250);
    expect(parseNewPrice('8 250 €').price, 8250);
    expect(parseNewPrice('8.250').price, 8250);
    expect(parseNewPrice('8250,50').price, 8250.5);
    expect(parseNewPrice('  '), (price: null, error: null));
    expect(parseNewPrice('abc').error, 'Preço inválido');
    expect(parseNewPrice('0').error, 'Preço inválido');
  });
}
