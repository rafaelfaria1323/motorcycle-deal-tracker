import 'package:collector/collector.dart';
import 'package:test/test.dart';

const _valid = '''
[
  {"url": "https://example.com/a", "brand": "Yamaha", "model": "R7",
   "year": 2026, "mileage_km": 3500, "price_eur": 9300,
   "seller_type": "dealer", "location": "Lisboa",
   "images": ["https://example.com/a.jpg"]},
  {"url": "https://example.com/b", "brand": "Honda", "model": "CB650R",
   "price_eur": 8250.5}
]
''';

void main() {
  final adapter = ManualAdapter('unused.json');

  test('parses valid records and keeps optional fields empty', () {
    final result = adapter.parse(_valid);

    expect(result.issues, isEmpty);
    expect(result.records, hasLength(2));
    expect(result.records.first.mileageKm, 3500);
    expect(result.records.first.images, hasLength(1));
    expect(result.records.last.year, isNull);
    expect(result.records.last.priceEur, 8250.5);
    expect(result.records.last.images, isEmpty);
  });

  test('reports a bad record but keeps the others', () {
    final result = adapter.parse('''
[
  {"url": "https://example.com/a", "brand": "Yamaha", "model": "R7"},
  {"url": "https://example.com/b", "brand": "Honda", "model": "CB650R",
   "price_eur": 8250}
]''');

    expect(result.records, hasLength(1));
    expect(result.issues.single.index, 0);
    expect(result.issues.single.message, contains('price_eur'));
  });

  test('rejects links that are not http(s)', () {
    final result = adapter.parse(
      '[{"url": "ftp://x/y", "brand": "A", "model": "B", "price_eur": 1}]',
    );

    expect(result.records, isEmpty);
    expect(result.issues.single.message, contains('url'));
  });

  test('rejects wrong types and items that are not objects', () {
    final result = adapter.parse('''
[42, {"url": "https://example.com/a", "brand": "A", "model": "B",
      "price_eur": 1, "year": "2026"}]''');

    expect(result.records, isEmpty);
    expect(result.issues.map((i) => i.index), [0, 1]);
  });

  test('throws when the file is not a JSON array', () {
    expect(() => adapter.parse('{}'), throwsFormatException);
    expect(() => adapter.parse('not json'), throwsFormatException);
  });
}
