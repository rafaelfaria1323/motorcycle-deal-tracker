import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, dynamic> param(String key, String value, [String? normalized]) => {
  'key': key,
  'value': value,
  'normalizedValue': normalized ?? value,
};

Map<String, dynamic> ad({
  int id = 1,
  String title = 'Yamaha MT-07 35Kw',
  String model = 'MT-07',
  int? price = 7400,
  String year = '2024',
  bool business = false,
  String userName = 'Paula Teixeira',
  String company = '',
  String partner = '',
  String? externalUrl,
}) => {
  'id': id,
  'title': title,
  'url': 'https://www.olx.pt/d/anuncio/x-ID$id.html',
  'status': 'active',
  'description': 'Para venda Mt-07<br />\nDeslimitada<br />\n',
  'isBusiness': business,
  'params': [
    param('modelo', model, model.toLowerCase()),
    param('year', year),
    param('quilometros', '10.000 km', '10000'),
    param('cilindrada', '501 - 1000 cc', '501-1000-cc'),
  ],
  'price': {
    'regularPrice': price == null
        ? null
        : {'value': price, 'currencyCode': 'EUR'},
  },
  'location': {'cityName': 'Fafe', 'regionName': 'Braga'},
  'user': {'name': userName, 'company_name': company},
  'partner': {'code': partner},
  'externalUrl': externalUrl,
  'photos': ['https://img.example.com/$id.jpg'],
  'createdTime': '2026-05-18T20:08:50+01:00',
  'lastRefreshTime': '2026-10-19T14:00:16+01:00',
};

String searchPage(
  List<Map<String, dynamic>> ads, {
  int page = 0,
  int totalPages = 1,
  List<Map<String, Object?>>? models,
}) {
  final state = {
    'listing': {
      'listing': {
        'pageNumber': page,
        'totalPages': totalPages,
        'totalElements': ads.length * totalPages,
        'ads': ads,
        if (models != null)
          'metaData': {
            'filters': [
              {'name': 'filter_enum_cilindrada', 'values': <Object>[]},
              {'name': 'filter_enum_modelo', 'values': models},
            ],
          },
        'requestParams': {
          'page': page,
          'categoryPath': 'carros-motos-e-barcos/motociclos-scooters/yamaha',
          'params': {
            'search[filter_enum_modelo][0]': 'mt-07',
            if (page > 0) 'page': '$page',
          },
        },
      },
    },
  };
  return '<script>window.__PRERENDERED_STATE__= '
      '${jsonEncode(jsonEncode(state))};</script>';
}

final adapter = OlxSearchAdapter('unused');
final mapper = OlxMapper(
  Catalog(const [mt07Entry, r7Entry]),
  currentYear: 2026,
);

OlxRawListing one(Map<String, dynamic> a) =>
    adapter.parseSearchPage(searchPage([a])).records.single;

void main() {
  test('reads the models OLX offers for the brand of the page', () {
    final page = adapter.parseSearchPage(
      searchPage(
        [ad()],
        models: [
          {'label': 'MT-07', 'value': 'mt-07'},
          {'label': 'Ténéré 700', 'value': 'tenere-700'},
          {'label': '', 'value': 'blank'},
        ],
      ),
    );

    expect(
      [for (final m in page.models) '${m.makeId}/${m.modelId}/${m.modelName}'],
      ['yamaha/mt-07/MT-07', 'yamaha/tenere-700/Ténéré 700'],
    );
    expect(page.models.first.ads, isNull);
    expect(adapter.parseSearchPage(searchPage([ad()])).models, isEmpty);
  });

  test('uniqueSiteModels keeps one entry per brand and model', () {
    const mt07 = SiteModel(
      makeId: 'yamaha',
      makeName: 'Yamaha',
      modelId: 'mt-07',
      modelName: 'MT-07',
    );
    const r = SiteModel(
      makeId: 'yamaha',
      makeName: 'Yamaha',
      modelId: 'r',
      modelName: 'R',
    );

    expect(uniqueSiteModels([mt07, r, mt07]), [mt07, r]);
    expect(mt07.toRow('olx'), {
      'source': 'olx',
      'make_id': 'yamaha',
      'make_name': 'Yamaha',
      'model_id': 'mt-07',
      'model_name': 'MT-07',
      'ads': null,
    });
  });

  test('reads a result and maps it to the catalog model', () {
    final raw = one(ad());

    expect(raw.id, '1');
    expect(raw.categoryBrand, 'yamaha');
    expect(raw.model, 'MT-07');
    expect(raw.year, 2024);
    expect(raw.mileageKm, 10000);
    expect(raw.location, 'Fafe');
    expect(raw.description, 'Para venda Mt-07\nDeslimitada');

    final listing = (mapper.map(raw) as Mapped).listing;
    expect(listing.source, 'olx');
    expect(listing.sourceListingId, 'olx.pt/1');
    expect(listing.motorcycleSlug, 'yamaha-mt-07');
    expect(listing.brand, 'Yamaha');
    expect(listing.price, 7400);
    expect(listing.sellerType, SellerType.private);
  });

  test("a private seller's name is never read", () {
    expect(one(ad()).businessName, isNull);
    expect(
      one(ad(business: true, userName: 'dmmotos72')).businessName,
      'dmmotos72',
    );
    expect(
      one(ad(business: true, company: 'Machados - Yamaha Motos')).businessName,
      'Machados - Yamaha Motos',
    );
  });

  test('a business account named "Particular" is a private seller', () {
    final raw = one(ad(business: true, userName: 'Particular'));

    expect(raw.isBusiness, isFalse);
    expect(raw.businessName, isNull);
  });

  test('a Tracer 7 filed under MT-07 stays unmatched, under its title', () {
    final raw = one(ad(title: 'Yamaha Tracer 7 2023'));
    final listing = (mapper.map(raw) as Mapped).listing;

    expect(listing.motorcycleSlug, isNull);
    expect(listing.model, 'Tracer 7 2023');
  });

  test('a copy of a Standvirtual ad is skipped but still counts as live', () {
    const url = 'https://www.standvirtual.com/motos/anuncio/x-ID8Q0wf4.html';
    final raw = one(ad(partner: 'standvirtual', externalUrl: url));

    expect(mapper.map(raw), isA<Rejected>());
    final batch = SourceBatch('olx', const [], [
      MappedRecord(raw.url, mapper.map(raw), liveId: OlxMapper.listingId('1')),
    ]);
    expect(liveIds(batch), ['olx.pt/1']);
  });

  test('a page that is not a search page is a format error', () {
    expect(
      () => adapter.parseSearchPage('<html></html>'),
      throwsFormatException,
    );
  });

  group('a search over several pages', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('olx'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('is incomplete until every page is saved', () async {
      File(
        '${dir.path}/p1.html',
      ).writeAsStringSync(searchPage([ad(id: 1)], totalPages: 2));
      final partial = await OlxSearchAdapter(dir.path).read();
      expect(partial.issues.single.message, contains('1 of 2 page(s)'));

      File(
        '${dir.path}/p2.html',
      ).writeAsStringSync(searchPage([ad(id: 2)], page: 2, totalPages: 2));
      final full = await OlxSearchAdapter(dir.path).read();
      expect(full.issues, isEmpty);
      expect(full.records.map((r) => r.id), ['1', '2']);
    });

    test('a manifest ties records and problems to their search', () async {
      const url = 'https://www.olx.pt/carros-motos-e-barcos/x/';
      File(
        '${dir.path}/p1.html',
      ).writeAsStringSync(searchPage([ad(id: 1)], totalPages: 2));
      await const SearchManifest(
        planned: [url],
        files: {'p1.html': url},
      ).writeTo(dir.path);

      final result = await OlxSearchAdapter(dir.path).read();

      expect(result.recordSearches, [url]);
      expect(result.issues.single.search, url);
      expect(result.manifest!.fetched, {url});
    });

    test('without a manifest nothing is tied to a search', () async {
      File('${dir.path}/p1.html').writeAsStringSync(searchPage([ad(id: 1)]));

      final result = await OlxSearchAdapter(dir.path).read();

      expect(result.recordSearches, isNull);
      expect(result.manifest, isNull);
    });
  });

  test('later pages keep the search filters', () {
    final search = Uri.parse(
      'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/'
      '?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07'
      '&search%5Bfilter_float_year:from%5D=2023',
    );
    final page = OlxSearchAdapter.pageUrl(search, 3);

    expect(page.path, search.path);
    expect(page.queryParameters, {
      'search[filter_enum_modelo][0]': 'mt-07',
      'search[filter_float_year:from]': '2023',
      'page': '3',
    });
    expect(urlProblem(page, site: FetchSite.olx), isNull);
  });

  test('the model is found after OLX\'s family and the brand', () {
    for (final title in [
      'Yamaha YZF-R7 [2024] [3500]km',
      'Moto Yamaha YZF R7 2024',
      'YZF-R7 impecável',
    ]) {
      final raw = one(ad(title: title, model: 'YZF'));
      final listing = (mapper.map(raw) as Mapped).listing;
      expect(listing.motorcycleSlug, 'yamaha-r7', reason: title);
    }
  });

  test('keeps when the ad was published and when it was renewed', () {
    final listing = (mapper.map(one(ad())) as Mapped).listing;

    expect(listing.publishedAt, DateTime.utc(2026, 5, 18, 19, 8, 50));
    expect(listing.siteRefreshedAt, DateTime.utc(2026, 10, 19, 13, 0, 16));
  });

  test('an ad without a price is skipped, not a read problem', () {
    final page = adapter.parseSearchPage(searchPage([ad(price: null)]));

    expect(page.problems, isEmpty);
    expect(mapper.map(page.records.single), isA<Rejected>());
  });

  test('long addresses of different pages get different file names', () {
    final search = Uri.parse(
      'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/honda/'
      '?search%5Bfilter_enum_modelo%5D%5B0%5D=cb'
      '&search%5Bfilter_enum_modelo%5D%5B1%5D=cbr'
      '&search%5Bfilter_float_year:from%5D=2023',
    );
    final names = {
      for (var p = 2; p <= 4; p++)
        fileNameFor(OlxSearchAdapter.pageUrl(search, p)),
      fileNameFor(search),
    };

    expect(names.length, 4);
    expect(names.every((n) => n.length <= 155 && n.endsWith('.html')), isTrue);
  });
}
