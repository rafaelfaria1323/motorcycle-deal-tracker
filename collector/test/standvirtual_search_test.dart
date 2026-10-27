import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

import 'helpers.dart';

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
  String currency = 'EUR',
  String year = '2024',
  String? cc,
}) => {
  'id': id,
  'url': 'https://www.standvirtual.com/motos/anuncio/x-ID$id.html',
  'price': {
    'amount': {'value': price, 'currencyCode': currency},
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

String searchPage(
  List<Map<String, dynamic>> nodes, {
  int? total,
  int offset = 0,
  String? bumpDate,
  Map<String, dynamic>? filters,
  List<Map<String, dynamic>> topAds = const [],
}) {
  final search = {
    'advertSearch': {
      'totalCount': total ?? nodes.length,
      'pageInfo': {'pageSize': 32, 'currentOffset': offset},
      'topads': [
        for (final n in topAds) {'node': n},
      ],
      'edges': [
        for (final n in nodes)
          {
            'vas': {'bumpDate': bumpDate},
            'node': n,
          },
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
          if (filters != null)
            'c': {
              'data': jsonEncode({'filters': filters}),
            },
        },
      },
    },
  };
  return "<script type='application/json' id='__NEXT_DATA__'>"
      '${jsonEncode(data)}</script>';
}

final adapter = StandvirtualSearchAdapter('unused');
final catalog = Catalog(const [mt07Entry]);

Map<String, dynamic> filterState(
  String filterId,
  List<Map<String, Object?>> values, {
  String? make,
}) => {
  'filterId': filterId,
  'conditions': [
    if (make != null) {'filterId': 'filter_enum_make', 'value': make},
  ],
  'values': [
    {'name': null, 'values': values},
  ],
};

void main() {
  test('reads the brand and model lists of the filters', () {
    final page = adapter.parseSearchPage(
      searchPage(
        [node()],
        filters: {
          'states': [
            filterState('filter_enum_make', [
              {'id': 'honda', 'name': 'Honda', 'counter': 361},
            ]),
            filterState('filter_enum_model', [
              {'id': 'forza', 'name': 'Forza', 'counter': 32},
              {'id': 'cb', 'name': 'CB ', 'counter': 52},
              {'id': 'blank', 'name': ' '},
            ], make: 'honda'),
            // A brand missing from the brand list is left out.
            filterState('filter_enum_model', [
              {'id': 'x', 'name': 'X', 'counter': 1},
            ], make: 'unknown'),
            filterState('filter_enum_color', [
              {'id': 'red', 'name': 'Vermelho'},
            ]),
          ],
        },
      ),
    );

    expect(
      [
        for (final m in page.models)
          '${m.makeName}/${m.modelId}/${m.modelName}/${m.ads}',
      ],
      ['Honda/forza/Forza/32', 'Honda/cb/CB/52'],
    );
    expect(page.records, hasLength(1));
    expect(adapter.parseSearchPage(searchPage([node()])).models, isEmpty);
  });

  test('a model list belongs to the brand its brand condition names', () {
    final page = adapter.parseSearchPage(
      searchPage(
        [node()],
        filters: {
          'states': [
            filterState('filter_enum_make', [
              {'id': 'honda', 'name': 'Honda'},
              {'id': 'yamaha', 'name': 'Yamaha'},
            ]),
            {
              ...filterState('filter_enum_model', [
                {'id': 'forza', 'name': 'Forza'},
              ]),
              'conditions': [
                {'filterId': 'filter_enum_make', 'value': null},
                {'filterId': 'filter_enum_body_type', 'value': 'yamaha'},
                {'filterId': 'filter_enum_make', 'value': 'honda'},
              ],
            },
          ],
        },
      ),
    );

    expect(
      [for (final m in page.models) '${m.makeName}/${m.modelName}'],
      ['Honda/Forza'],
    );
  });

  test('reads every listing of a search page', () {
    final page = adapter.parseSearchPage(
      searchPage([
        node(version: 'Abs'),
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
      searchPage([node(), node(id: '2')], total: 40),
    );

    expect(page.isComplete, isFalse);
    expect(page.total, 40);
    expect(page.totalPages, 2);
  });

  group('a search over several pages', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('standvirtual'));
    tearDown(() => dir.deleteSync(recursive: true));

    const url = 'https://www.standvirtual.com/motos/yamaha/mt-07';
    final first = [for (var i = 1; i <= 32; i++) node(id: '$i')];

    test('a rejected ad still on the site counts as seen', () async {
      File(
        '${dir.path}/p1.html',
      ).writeAsStringSync(searchPage([node(), node(id: '2', currency: 'GBP')]));
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url},
      ).writeTo(dir.path);

      final batch = await loadBatch('standvirtual-search', dir.path, catalog);
      final plan = removalPlan(batch);

      expect(batch.records[1].outcome, isA<Rejected>());
      expect(plan.searches, [url]);
      expect(
        plan.seenIds,
        unorderedEquals([
          StandvirtualMapper.listingId('1'),
          StandvirtualMapper.listingId('2'),
        ]),
      );
    });

    test('is incomplete until every page is saved', () async {
      File(
        '${dir.path}/p1.html',
      ).writeAsStringSync(searchPage(first, total: 33));
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url},
      ).writeTo(dir.path);
      final partial = await StandvirtualSearchAdapter(dir.path).read();
      expect(partial.issues.single.message, contains('holds 32 of 33'));
      expect(partial.issues.single.search, url);

      File(
        '${dir.path}/p2.html',
      ).writeAsStringSync(searchPage([node(id: '33')], total: 33, offset: 32));
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url, 'p2.html': url},
      ).writeTo(dir.path);
      final full = await StandvirtualSearchAdapter(dir.path).read();
      expect(full.issues, isEmpty);
      expect(full.records, hasLength(33));
    });

    for (final total in [32, 33]) {
      test(
        'duplicate offsets cannot make a $total-listing search removable',
        () async {
          for (final name in ['p1.html', 'p2.html']) {
            File(
              '${dir.path}/$name',
            ).writeAsStringSync(searchPage(first, total: total));
          }
          await const SearchManifest(
            planned: [url],
            files: {'p1.html': url, 'p2.html': url},
          ).writeTo(dir.path);

          final batch = await loadBatch(
            'standvirtual-search',
            dir.path,
            catalog,
          );
          final plan = removalPlan(batch);

          expect(batch.issues, hasLength(1));
          expect(
            batch.issues.single.message,
            contains('duplicate page offset'),
          );
          expect(batch.issues.single.message, contains('holds 32 of $total'));
          expect(batch.issues.single.search, url);
          expect(plan.searches, isNull);
          expect(plan.seenIds, isEmpty);
          expect(plan.includeUnkeyed, isFalse);
        },
      );
    }

    test(
      'the full listing count can complete a search before every page',
      () async {
        File(
          '${dir.path}/p1.html',
        ).writeAsStringSync(searchPage([...first, node(id: '33')], total: 33));
        await const SearchManifest(
          planned: [url],
          files: {'p1.html': url},
        ).writeTo(dir.path);

        final full = await StandvirtualSearchAdapter(dir.path).read();

        expect(full.issues, isEmpty);
        expect(full.records, hasLength(33));
      },
    );

    test('promoted ads never make a search cut short look read', () async {
      // 32 results and 2 promoted ads on page 1 of a 34-listing search.
      File('${dir.path}/p1.html').writeAsStringSync(
        searchPage(
          first,
          total: 34,
          topAds: [
            node(),
            node(id: '2'),
          ],
        ),
      );
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url},
      ).writeTo(dir.path);

      final partial = await StandvirtualSearchAdapter(dir.path).read();

      expect(partial.issues.single.message, contains('holds 32 of 34'));
    });

    test('every page saved is read in full, whatever the count', () async {
      // The site's count may include listings shown on no page.
      File(
        '${dir.path}/p1.html',
      ).writeAsStringSync(searchPage(first, total: 34));
      File(
        '${dir.path}/p2.html',
      ).writeAsStringSync(searchPage([node(id: '33')], total: 34, offset: 32));
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url, 'p2.html': url},
      ).writeTo(dir.path);

      final full = await StandvirtualSearchAdapter(dir.path).read();

      expect(full.issues, isEmpty);
    });
  });

  test('a result without a price is a problem, not a crash', () {
    final bad = node(id: '3')..['price'] = {'amount': <String, Object?>{}};
    final page = adapter.parseSearchPage(searchPage([node(), bad]));

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
      searchPage([node(), node(id: '2', version: 'tracer')]),
    );

    final slugs = [
      for (final r in page.records)
        (mapper.map(r) as Mapped).listing.motorcycleSlug,
    ];

    expect(slugs, ['yamaha-mt-07', null]);
  });

  test('publication and bump dates reach the normalized listing', () {
    final mapper = StandvirtualMapper(catalog, currentYear: 2026);
    final page = adapter.parseSearchPage(
      searchPage([
        node()..['createdAt'] = '2026-10-08T18:31:14Z',
        node(id: '2'),
      ], bumpDate: '2026-10-18T18:30:00Z'),
    );

    final listing = (mapper.map(page.records.first) as Mapped).listing;
    expect(listing.publishedAt, DateTime.utc(2026, 10, 8, 18, 31, 14));
    expect(listing.siteRefreshedAt, DateTime.utc(2026, 10, 18, 18, 30));
    expect(page.records.last.createdAt, isNull);
  });

  // Saved pages are never committed, so this only runs on Rafael's machine.
  final savedPage = File('samples/standvirtual/search/motos-yamaha-mt-07.html');
  test(
    'a saved search page has every listing\'s publication date',
    skip: savedPage.existsSync() ? false : 'no saved search page here',
    () async {
      final page = adapter.parseSearchPage(await savedPage.readAsString());

      expect(page.records, isNotEmpty);
      expect(page.records.every((r) => r.createdAt != null), isTrue);
      // Only ads the seller pushed back to the top have a bump date.
      expect(page.records.any((r) => r.bumpedAt != null), isTrue);
    },
  );

  group('price cuts the site reports', () {
    Map<String, dynamic> drop(int minor, {String currency = 'EUR'}) => {
      'percentage': 4.41,
      'lowestPrice': {'currencyCode': currency, 'minorAmount': minor},
    };

    test('the price before the cut reaches the normalized listing', () {
      final mapper = StandvirtualMapper(catalog, currentYear: 2026);
      final page = adapter.parseSearchPage(
        searchPage([
          node(price: '6500')..['priceDrop'] = drop(680000),
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
