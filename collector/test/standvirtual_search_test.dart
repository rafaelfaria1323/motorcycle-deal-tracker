import 'dart:convert';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

Map<String, String> p(String key, String value) => {
  'key': key,
  'displayValue': value,
  'value': value,
};

Map<String, dynamic> node({
  String id = '1',
  String model = 'MT-07',
  String? version,
  String seller = 'ProfessionalSeller',
  String? sellerName = 'Stand Exemplo',
  String city = 'Viseu',
  String price = '7500',
  String year = '2024',
  String? cc,
}) => {
  'id': id,
  'url': 'https://www.standvirtual.com/motos/anuncio/x-ID$id.html',
  'price': {
    'amount': {'value': price, 'currencyCode': 'EUR'},
  },
  'location': {
    'city': {'name': city},
    'region': {'name': 'Santarém'},
  },
  'parameters': [
    p('make', 'Yamaha'),
    p('model', model),
    if (version != null) p('version', version),
    p('mileage', '4383'),
    p('first_registration_year', year),
    if (cc != null) p('engine_capacity', cc),
  ],
  'seller': {'__typename': seller},
  'sellerLink': sellerName == null ? null : {'name': sellerName},
  'thumbnail': {'x2': 'https://img.example.com/$id.jpg'},
};

String searchPage(List<Map<String, dynamic>> nodes, {int? total}) {
  final search = {
    'advertSearch': {
      'totalCount': total ?? nodes.length,
      'pageInfo': {'pageSize': 32, 'currentOffset': 0},
      'topads': <Object>[],
      'edges': [
        for (final n in nodes) {'node': n},
      ],
    },
  };
  final data = {
    'props': {
      'pageProps': {
        'urqlState': {
          'a': {
            'data': jsonEncode({'sortOptions': <String, Object>{}}),
          },
          'b': {'data': jsonEncode(search)},
        },
      },
    },
  };
  return '<script id="__NEXT_DATA__" type="application/json">'
      '${jsonEncode(data)}</script>';
}

final adapter = StandvirtualSearchAdapter('unused');
final catalog = Catalog(const [
  CatalogEntry(
    slug: 'yamaha-mt-07',
    brand: 'Yamaha',
    model: 'MT-07',
    minYear: 2023,
  ),
]);

void main() {
  test('reads every listing of a search page', () {
    final page = adapter.parseSearchPage(
      searchPage([
        node(id: '1', version: 'Abs'),
        node(
          id: '2',
          seller: 'PrivateSeller',
          sellerName: null,
          city: 'Santarém (Marvila), Santa Iria da Ribeira de Santarém e',
        ),
      ]),
    );

    expect(page.records.length, 2);
    expect(page.isComplete, isTrue);

    final first = page.records.first;
    expect(first.id, '1');
    expect(first.brand, 'Yamaha');
    expect(first.model, 'MT-07');
    expect(first.version, 'Abs');
    expect(first.price, 7500);
    expect(first.year, 2024);
    expect(first.mileageKm, 4383);
    expect(first.sellerType, 'dealer');
    expect(first.sellerName, 'Stand Exemplo');
    expect(first.location, 'Viseu');
    expect(first.images, ['https://img.example.com/1.jpg']);

    final second = page.records.last;
    expect(second.sellerType, 'private');
    expect(second.sellerName, isNull);
    // A long list of parishes falls back to the district.
    expect(second.location, 'Santarém');
  });

  test('a page showing fewer listings than the search has is incomplete', () {
    final page = adapter.parseSearchPage(
      searchPage([node(id: '1'), node(id: '2')], total: 40),
    );

    expect(page.isComplete, isFalse);
    expect(page.total, 40);
  });

  test('a result without a price is a problem, not a crash', () {
    final bad = node(id: '3')..['price'] = {'amount': {}};
    final page = adapter.parseSearchPage(searchPage([node(id: '1'), bad]));

    expect(page.records.length, 1);
    expect(page.problems.length, 1);
  });

  test('a page that is not a search page is a format error', () {
    expect(
      () => adapter.parseSearchPage('<html></html>'),
      throwsFormatException,
    );
    expect(
      () => adapter.parseSearchPage(
        '<script id="__NEXT_DATA__">{"props":{"pageProps":{}}}</script>',
      ),
      throwsFormatException,
    );
  });

  test('maps through the same rules as a listing page', () {
    final mapper = StandvirtualMapper(catalog, currentYear: 2026);
    final page = adapter.parseSearchPage(
      searchPage([node(id: '1'), node(id: '2', version: 'tracer')]),
    );

    final slugs = [
      for (final r in page.records)
        (mapper.map(r) as Mapped).listing.motorcycleSlug,
    ];

    expect(slugs, ['yamaha-mt-07', null]);
  });

  group('price cuts the site reports', () {
    Map<String, dynamic> drop(int minor, {String currency = 'EUR'}) => {
      'percentage': 4.41,
      'lowestPrice': {'currencyCode': currency, 'minorAmount': minor},
    };

    test('the price before the cut reaches the normalized listing', () {
      final mapper = StandvirtualMapper(catalog, currentYear: 2026);
      final page = adapter.parseSearchPage(
        searchPage([
          node(id: '1', price: '6500')..['priceDrop'] = drop(680000),
          node(id: '2')..['priceDrop'] = null,
        ]),
      );

      expect(page.records.first.priceBeforeDrop, 6800);
      expect(page.records.last.priceBeforeDrop, isNull);
      final listing = (mapper.map(page.records.first) as Mapped).listing;
      expect(listing.priceBeforeDrop, 6800.0);
    });

    test('only a euro price above the current one counts', () {
      expect(priceBeforeDrop(drop(680000), 6500), 6800);
      expect(priceBeforeDrop(drop(650000), 6500), isNull);
      expect(priceBeforeDrop(drop(680000, currency: 'USD'), 6500), isNull);
      expect(priceBeforeDrop({'percentage': 1}, 6500), isNull);
      expect(priceBeforeDrop(null, 6500), isNull);
    });
  });
}
