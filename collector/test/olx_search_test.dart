import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

Map<String, dynamic> param(String key, String value, [String? normalized]) => {
  'key': key,
  'value': value,
  'normalizedValue': normalized ?? value,
};

Map<String, dynamic> ad({
  int id = 1,
  String title = 'Yamaha MT-07 35Kw',
  int price = 7400,
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
    param('modelo', 'MT-07', 'mt-07'),
    param('year', year),
    param('quilometros', '10.000 km', '10000'),
    param('cilindrada', '501 - 1000 cc', '501-1000-cc'),
  ],
  'price': {
    'regularPrice': {'value': price, 'currencyCode': 'EUR'},
  },
  'location': {'cityName': 'Fafe', 'regionName': 'Braga'},
  'user': {'name': userName, 'company_name': company},
  'partner': {'code': partner},
  'externalUrl': externalUrl,
  'photos': ['https://img.example.com/$id.jpg'],
};

String searchPage(
  List<Map<String, dynamic>> ads, {
  int page = 0,
  int totalPages = 1,
}) {
  final state = {
    'listing': {
      'listing': {
        'pageNumber': page,
        'totalPages': totalPages,
        'totalElements': ads.length * totalPages,
        'ads': ads,
        'requestParams': {
          'page': page,
          'categoryPath': 'carros-motos-e-barcos/motociclos-scooters/yamaha',
          'params': {'search[filter_enum_modelo][0]': 'mt-07'},
        },
      },
    },
  };
  return '<script>window.__PRERENDERED_STATE__= '
      '${jsonEncode(jsonEncode(state))};</script>';
}

final adapter = OlxSearchAdapter('unused');
final mapper = OlxMapper(
  Catalog(const [
    CatalogEntry(
      slug: 'yamaha-mt-07',
      brand: 'Yamaha',
      model: 'MT-07',
      minYear: 2023,
    ),
  ]),
  currentYear: 2026,
);

OlxRawListing one(Map<String, dynamic> a) =>
    adapter.parseSearchPage(searchPage([a])).records.single;

void main() {
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
    expect(listing.model, 'Yamaha Tracer 7 2023');
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
  });
}
