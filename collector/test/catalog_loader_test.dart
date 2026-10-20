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
}
