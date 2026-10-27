import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  test('rows become entries in the order given', () {
    final catalog = catalogFromRows([
      {
        'id': 'id-1',
        'slug': 'yamaha-mt-07',
        'brand': 'Yamaha',
        'model': 'MT-07',
        'min_year': 2021,
        'aliases': ['MT07'],
        'excluded_words': ['tracer'],
        'engine_cc_min': 680,
        'engine_cc_max': 710,
        'olx_search': 'https://www.olx.pt/mt07',
        'standvirtual_search': 'https://www.standvirtual.com/mt07',
      },
      {
        'id': 'id-2',
        'slug': 'honda-cb125r',
        'brand': 'Honda',
        'model': 'CB125R',
        'min_year': 2019,
      },
    ]);

    expect(catalog.entries.map((e) => e.slug), [
      'yamaha-mt-07',
      'honda-cb125r',
    ]);
    final mt = catalog.entries.first;
    expect(mt.id, 'id-1');
    expect(mt.minYear, 2021);
    expect(mt.aliases, ['MT07']);
    expect(mt.excludedWords, ['tracer']);
    expect(mt.engineCcMin, 680);
    expect(mt.engineCcMax, 710);
    expect(mt.olxSearch, 'https://www.olx.pt/mt07');
    expect(mt.standvirtualSearch, 'https://www.standvirtual.com/mt07');
  });

  test('missing optional columns become empty lists and nulls', () {
    final entry = catalogFromRows([
      {
        'id': 'id-2',
        'slug': 'honda-cb125r',
        'brand': 'Honda',
        'model': 'CB125R',
        'min_year': 2019,
        'aliases': null,
        'excluded_words': null,
      },
    ]).entries.single;

    expect(entry.aliases, isEmpty);
    expect(entry.excludedWords, isEmpty);
    expect(entry.engineCcMin, isNull);
    expect(entry.olxSearch, isNull);
    expect(entry.standvirtualSearch, isNull);
  });

  test('no rows give an empty catalog', () {
    expect(catalogFromRows(const []).entries, isEmpty);
  });

  group('lookups', () {
    const cb650r = CatalogEntry(
      slug: 'honda-cb650r',
      brand: 'Honda',
      model: 'CB650R',
      minYear: 2023,
    );
    const mt07 = CatalogEntry(
      slug: 'yamaha-mt-07',
      brand: 'Yamaha',
      model: 'MT-07',
      minYear: 2021,
    );
    final catalog = Catalog(const [cb650r, mt07]);

    test('find needs the brand and the model, spelled loosely', () {
      expect(catalog.find('yamaha', 'mt07'), mt07);
      expect(catalog.find('Honda', 'MT-07'), isNull);
      expect(catalog.find('Yamaha', 'MT-09'), isNull);
    });

    test('a near miss is a longer name of a model of the same brand', () {
      expect(catalog.nearMiss('Yamaha', 'MT-07 ABS'), mt07);
      expect(catalog.nearMiss('Honda', 'MT-07 ABS'), isNull);
      expect(catalog.nearMiss('Yamaha', 'Tracer 7'), isNull);
    });
  });
}
