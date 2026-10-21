import 'package:collector/collector.dart';
import 'package:test/test.dart';

ManualRawListing _raw({
  String brand = 'Yamaha',
  String model = 'R7',
  num price = 9300,
  int? year = 2026,
  int? mileage = 3500,
  String? sellerType = 'dealer',
  String? sellerName = 'Stand Exemplo',
  List<String> images = const [],
}) {
  return ManualRawListing(
    url: 'https://example.com/a',
    brand: brand,
    model: model,
    priceEur: price,
    year: year,
    mileageKm: mileage,
    sellerType: sellerType,
    sellerName: sellerName,
    images: images,
  );
}

Mapped _mapped(MapOutcome outcome) {
  expect(outcome, isA<Mapped>());
  return outcome as Mapped;
}

void main() {
  final mapper = ManualMapper(Catalog.mvp(), currentYear: 2026);

  test('matches the catalog ignoring case and punctuation', () {
    final m = _mapped(mapper.map(_raw(brand: 'YAMAHA', model: 'mt 07')));

    expect(m.listing.motorcycleSlug, 'yamaha-mt-07');
    expect(m.listing.model, 'MT-07');
    expect(m.warnings, isEmpty);
  });

  test('keeps unknown models but warns, with a hint for variants', () {
    final unknown = _mapped(mapper.map(_raw(brand: 'Suzuki', model: 'SV650')));
    expect(unknown.listing.motorcycleSlug, isNull);
    expect(unknown.warnings.single, contains('not a followed model'));

    final near = _mapped(mapper.map(_raw(model: 'MT-07 ABS')));
    expect(near.listing.motorcycleSlug, isNull);
    expect(near.warnings.single, contains('variant'));
  });

  test('rejects years below the tracked range or out of range', () {
    final low = mapper.map(_raw(year: 2024));
    expect(low, isA<Rejected>());
    expect((low as Rejected).reason, contains('below'));

    final old = mapper.map(_raw(year: 1970));
    expect((old as Rejected).reason, contains('out of range'));
  });

  test('rejects a zero price and impossible mileage', () {
    expect(mapper.map(_raw(price: 0)), isA<Rejected>());
    expect(mapper.map(_raw(mileage: -1)), isA<Rejected>());
    expect(mapper.map(_raw(mileage: 900000)), isA<Rejected>());
  });

  test('keeps seller names only for dealers', () {
    final dealer = _mapped(mapper.map(_raw()));
    expect(dealer.listing.sellerName, 'Stand Exemplo');

    final priv = _mapped(
      mapper.map(_raw(sellerType: 'particular', sellerName: 'João M.')),
    );
    expect(priv.listing.sellerType, SellerType.private);
    expect(priv.listing.sellerName, isNull);
    expect(priv.warnings.single, contains('seller_name'));
  });

  test('handles missing and unknown seller types', () {
    final missing = _mapped(
      mapper.map(_raw(sellerType: null, sellerName: null)),
    );
    expect(missing.listing.sellerType, SellerType.unknown);
    expect(missing.warnings, isEmpty);

    final odd = _mapped(
      mapper.map(_raw(sellerType: 'banana', sellerName: null)),
    );
    expect(odd.listing.sellerType, SellerType.unknown);
    expect(odd.warnings.single, contains('banana'));
  });

  test('drops invalid and duplicate image links', () {
    final m = _mapped(
      mapper.map(
        _raw(
          images: [
            'https://example.com/1.jpg',
            'https://example.com/1.jpg',
            'ftp://x/2.jpg',
          ],
        ),
      ),
    );

    expect(m.listing.images, ['https://example.com/1.jpg']);
    expect(m.warnings.single, contains('image'));
  });

  test('derives the source and id from the url', () {
    final m = _mapped(mapper.map(_raw()));

    expect(m.listing.source, 'manual');
    expect(m.listing.sourceListingId, 'example.com/a');
  });
}
