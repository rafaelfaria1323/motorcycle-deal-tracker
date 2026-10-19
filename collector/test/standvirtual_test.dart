import 'dart:convert';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

String page(Map<String, dynamic> advert) {
  final data = {
    'props': {
      'pageProps': {'advert': advert},
    },
  };
  return '<html><script id="__NEXT_DATA__" type="application/json">'
      '${jsonEncode(data)}</script></html>';
}

Map<String, dynamic> param(String value, [String? label]) => {
  'values': [
    {'value': value, 'label': label ?? value},
  ],
};

Map<String, dynamic> advert({
  String status = 'ACTIVE',
  String description = '<p>Mota muito cuidada.</p>',
  String year = '2025',
  String make = 'Yamaha',
  String model = 'MT-07',
  String? version,
  String? cc,
}) => {
  'id': '123456',
  'url': 'https://www.standvirtual.com/motos/anuncio/example-IDx.html',
  'status': status,
  'price': {'value': '7800', 'currency': 'EUR'},
  'parametersDict': {
    'make': param(make.toLowerCase(), make),
    'model': param(model.toLowerCase(), model),
    if (version != null) 'version': param(version),
    'first_registration_year': param(year),
    'mileage': param('4383', '4 383 km'),
    if (cc != null) 'engine_capacity': param(cc),
  },
  'seller': {
    'type': 'PROFESSIONAL',
    'name': 'Stand Exemplo',
    'location': {
      'shortAddress':
          'Rua X, Y - 2000-000 Cidade, concelho Santarém (Portugal)',
    },
  },
  'description': description,
  'images': {
    'photos': [
      {'url': 'https://img.example.com/1.jpg'},
    ],
  },
};

final adapter = StandvirtualPageAdapter('unused');
final catalog = Catalog(const [
  CatalogEntry(
    slug: 'yamaha-mt-07',
    brand: 'Yamaha',
    model: 'MT-07',
    minYear: 2023,
  ),
  CatalogEntry(slug: 'yamaha-r7', brand: 'Yamaha', model: 'R7', minYear: 2023),
  CatalogEntry(
    slug: 'honda-cb650r',
    brand: 'Honda',
    model: 'CB650R',
    minYear: 2023,
  ),
  CatalogEntry(
    slug: 'honda-cbr650r',
    brand: 'Honda',
    model: 'CBR650R',
    minYear: 2023,
  ),
]);

MapOutcome mapAd(Map<String, dynamic> ad) => StandvirtualMapper(
  catalog,
  currentYear: 2026,
).map(adapter.parsePage(page(ad)));

String? slugOf(String make, String model, String? version, {String? cc}) {
  final outcome = mapAd(
    advert(make: make, model: model, version: version, cc: cc),
  );
  return (outcome as Mapped).listing.motorcycleSlug;
}

void main() {
  test('reads the fields of a listing page', () {
    final raw = adapter.parsePage(page(advert(version: 'Abs')));

    expect(raw.id, '123456');
    expect(raw.brand, 'Yamaha');
    expect(raw.model, 'MT-07');
    expect(raw.version, 'Abs');
    expect(raw.price, 7800);
    expect(raw.year, 2025);
    expect(raw.mileageKm, 4383);
    expect(raw.sellerType, 'dealer');
    expect(raw.location, 'Santarém');
    expect(raw.description, 'Mota muito cuidada.');
    expect(raw.images, ['https://img.example.com/1.jpg']);
  });

  test('a dealer\'s boilerplate description becomes empty', () {
    final raw = adapter.parsePage(
      page(
        advert(
          description:
              '<p>A informação disponibilizada, ainda que precisa, '
              'não dispensa a sua confirmação.</p>'
              '<p>Anúncio introduzido por rotina informática.</p>',
        ),
      ),
    );

    expect(raw.description, isNull);
  });

  test('a page without listing data is a format error', () {
    expect(() => adapter.parsePage('<html></html>'), throwsFormatException);
    expect(
      () => adapter.parsePage(
        '<script id="__NEXT_DATA__">{"props":{"pageProps":{}}}</script>',
      ),
      throwsFormatException,
    );
  });

  test('maps to the normalized listing with a stable id', () {
    final outcome = mapAd(advert());

    expect(outcome, isA<Mapped>());
    final listing = (outcome as Mapped).listing;
    expect(listing.source, 'standvirtual');
    expect(listing.sourceListingId, 'standvirtual.com/123456');
    expect(listing.motorcycleSlug, 'yamaha-mt-07');
    expect(listing.sellerName, 'Stand Exemplo');
  });

  test('rejects listings that are not active', () {
    expect(mapAd(advert(status: 'REMOVED_BY_USER')), isA<Rejected>());
  });

  test('rejects a year below the tracked range', () {
    expect(mapAd(advert(year: '2019')), isA<Rejected>());
  });

  group('model matching from family + version', () {
    test('MT-07 with or without a version', () {
      expect(slugOf('Yamaha', 'MT-07', null), 'yamaha-mt-07');
      expect(slugOf('Yamaha', 'MT-07', 'Abs'), 'yamaha-mt-07');
    });

    test('R7 however the seller wrote it', () {
      expect(slugOf('Yamaha', 'R', 'YZF-R7'), 'yamaha-r7');
      expect(slugOf('Yamaha', 'R', '7'), 'yamaha-r7');
      expect(slugOf('Yamaha', 'R', 'R7 35 kw carta A2'), 'yamaha-r7');
    });

    test('CB650R and CBR650R stay apart', () {
      expect(slugOf('Honda', 'CB', 'Cb650r'), 'honda-cb650r');
      expect(
        slugOf('Honda', 'CB', '650R  Possível Financiamento'),
        'honda-cb650r',
      );
      expect(slugOf('Honda', 'CBR', 'CBR650R'), 'honda-cbr650r');
      expect(slugOf('Honda', 'CBR', '650R E-CLUTCH 2026'), 'honda-cbr650r');
    });

    test('a bare family name is not a model', () {
      expect(slugOf('Yamaha', 'R', null), isNull);
      expect(slugOf('Honda', 'CB', null), isNull);
    });

    test('other bikes of the same family are not matched', () {
      expect(slugOf('Yamaha', 'R', '3'), isNull);
      expect(slugOf('Yamaha', 'R', 'R1'), isNull);
      expect(slugOf('Yamaha', 'MT-07', 'Tracer'), isNull);
      expect(slugOf('Honda', 'CB', '500F'), isNull);
    });

    test('the brand must agree', () {
      expect(slugOf('Honda', 'R', 'R7'), isNull);
    });
  });

  group('Honda codes and engine size', () {
    test('ABS and E-Clutch codes are still the CB650R', () {
      expect(slugOf('Honda', 'CB', '650 RA'), 'honda-cb650r');
      expect(slugOf('Honda', 'CB', '650 RAC E-CLUTCH'), 'honda-cb650r');
    });

    test('the engine size settles a bare family', () {
      expect(slugOf('Honda', 'CB', 'R', cc: '649'), 'honda-cb650r');
      expect(
        slugOf('Honda', 'CBR', '650 E-Clutch 35KW', cc: '649'),
        'honda-cbr650r',
      );
      expect(slugOf('Yamaha', 'R', null, cc: '689'), 'yamaha-r7');
    });

    test('without an engine size a bare family stays unmatched', () {
      expect(slugOf('Honda', 'CB', 'R'), isNull);
    });

    test('a size that does not fit rules the match out', () {
      expect(slugOf('Yamaha', 'R', 'R7', cc: '321'), isNull);
      expect(slugOf('Yamaha', 'R', '9 Ediçao 70 anos', cc: '890'), isNull);
    });

    test('a CB650F is not a CB650R, whatever the engine size', () {
      expect(slugOf('Honda', 'CB', '650 F', cc: '650'), isNull);
    });
  });

  test('reads the details a listing page adds', () {
    final ad = advert(description: '<p>Primeiro dono, revisões na marca.</p>')
      ..['originalCreatedAt'] = '2026-10-08T18:30:13Z';
    (ad['parametersDict'] as Map<String, dynamic>)
      ..['number_of_registrations'] = param('1')
      ..['complete_review_book'] = param('1', 'Sim')
      ..['origin'] = param('national', 'Nacional')
      ..['maker_warranty_valid_until_date'] = param('2028-02-24')
      ..['vendors_warranty_valid_until_date'] = param('24', '24 Meses');

    final details = adapter.parseDetails(page(ad));

    expect(details.sourceListingId, 'standvirtual.com/123456');
    expect(details.description, 'Primeiro dono, revisões na marca.');
    expect(details.registrations, 1);
    expect(details.serviceBook, isTrue);
    expect(details.origin, 'national');
    expect(details.warrantyUntil, '2028-02-24');
    expect(details.dealerWarrantyMonths, 24);
    expect(details.publishedAt, '2026-10-08T18:30:13Z');
  });

  test('missing facts stay unknown, not false', () {
    final details = adapter.parseDetails(page(advert()));

    expect(details.registrations, isNull);
    expect(details.serviceBook, isNull);
    expect(details.warrantyUntil, isNull);
  });

  test('text in the same paragraph as the boilerplate is kept', () {
    final raw = adapter.parsePage(
      page(
        advert(
          description:
              '<p>Mota impecável, revisões na marca. '
              'Anúncio introduzido por rotina informática. '
              'Todos os dados carecem de confirmação presencial.</p>',
        ),
      ),
    );

    expect(raw.description, 'Mota impecável, revisões na marca.');
  });

  test('lists and line breaks survive', () {
    final raw = adapter.parsePage(
      page(
        advert(
          description:
              '<p>Extras:</p><ul><li>Escape Akrapovic</li>'
              '<li>Quickshifter</li></ul><p>Primeiro dono<br>Livro de revisões</p>',
        ),
      ),
    );

    expect(
      raw.description,
      'Extras:\n- Escape Akrapovic\n- Quickshifter\nPrimeiro dono\n'
      'Livro de revisões',
    );
  });
}
