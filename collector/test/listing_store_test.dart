import 'package:collector/collector.dart';
import 'package:test/test.dart';

NormalizedListing _listing(String id) {
  return NormalizedListing(
    source: 'manual',
    sourceListingId: id,
    url: 'https://example.com/$id',
    brand: 'Yamaha',
    model: 'R7',
    price: 9300,
    sellerType: SellerType.dealer,
    sellerName: 'Stand Exemplo',
    images: const [],
    motorcycleSlug: 'yamaha-r7',
    year: 2026,
    mileage: 3500,
  );
}

void main() {
  test(
    'motorcycleIdFor finds the id by slug, null when unknown or unmatched',
    () {
      final ids = {'yamaha-r7': 'id-r7'};
      final unmatched = NormalizedListing(
        source: 'manual',
        sourceListingId: 'x',
        url: 'https://example.com/x',
        brand: 'Yamaha',
        model: 'XSR',
        price: 7000,
        sellerType: SellerType.dealer,
        images: const [],
      );

      expect(motorcycleIdFor(_listing('a'), ids), 'id-r7');
      expect(motorcycleIdFor(_listing('a'), const {}), isNull);
      expect(motorcycleIdFor(unmatched, ids), isNull);
    },
  );

  test('uniqueBySourceId keeps the first of each id', () {
    final listings = [_listing('a'), _listing('b'), _listing('a')];

    expect(uniqueBySourceId(listings).map((l) => l.sourceListingId), [
      'a',
      'b',
    ]);
  });

  test('uniqueBySourceId: the same id on two sites is two listings', () {
    final olx = NormalizedListing(
      source: 'olx',
      sourceListingId: 'a',
      url: 'https://www.olx.pt/d/anuncio/a.html',
      brand: 'Yamaha',
      model: 'R7',
      price: 8900,
      sellerType: SellerType.private,
      images: const [],
    );

    expect(uniqueBySourceId([_listing('a'), olx]), hasLength(2));
    expect(uniqueBySourceId(const []), isEmpty);
  });

  test('listingRow matches the listings columns', () {
    final row = listingRow(_listing('a'), 'uuid-1');

    expect(row['source'], 'manual');
    expect(row['source_listing_id'], 'a');
    expect(row['motorcycle_id'], 'uuid-1');
    expect(row['seller_type'], 'dealer');
    expect(row['price'], 9300.0);
    expect(row['price_before_drop'], isNull);
    expect(row.containsKey('status'), isFalse);
    expect(row.containsKey('first_seen_at'), isFalse);
    expect(row.containsKey('deal_score'), isFalse);
  });

  test('fromSite keeps every field but the site ones', () {
    final base = NormalizedListing(
      source: 'manual',
      sourceListingId: 'x',
      url: 'https://example.com/x',
      brand: 'Yamaha',
      model: 'MT-07',
      variant: '35 kW',
      price: 6500,
      priceBeforeDrop: 7000,
      sellerType: SellerType.private,
      images: const ['a.jpg'],
      motorcycleSlug: 'yamaha-mt-07',
      year: 2021,
      mileage: 9000,
      location: 'Porto',
      description: 'Muito estimada.',
    );
    final published = DateTime.utc(2026, 9, 1);
    final site = base.fromSite(
      source: 'olx',
      sourceListingId: '123',
      publishedAt: published,
    );

    expect(site.source, 'olx');
    expect(site.sourceListingId, '123');
    expect(site.publishedAt, published);
    expect(site.siteRefreshedAt, isNull);
    // Only the site says what the price was before a cut.
    expect(site.priceBeforeDrop, isNull);
    expect(
      [site.url, site.brand, site.model, site.variant, site.price],
      [base.url, base.brand, base.model, base.variant, base.price],
    );
    expect(
      [site.year, site.mileage, site.location, site.description],
      [base.year, base.mileage, base.location, base.description],
    );
    expect(site.images, base.images);
    expect(site.motorcycleSlug, base.motorcycleSlug);
  });

  test('readAllPages reads on until a short page', () async {
    final asked = <(int, int)>[];
    final rows = await readAllPages((from, to) async {
      asked.add((from, to));
      // 5 rows in all, 2 per page.
      return [
        for (var i = from; i <= to && i < 5; i++) {'n': i},
      ];
    }, pageSize: 2);

    expect(rows.map((r) => r['n']), [0, 1, 2, 3, 4]);
    expect(asked, [(0, 1), (2, 3), (4, 5)]);
  });

  test('readAllPages asks once more after an exactly full page', () async {
    var calls = 0;
    final rows = await readAllPages((from, to) async {
      calls++;
      return from == 0 ? [{}, {}] : [];
    }, pageSize: 2);

    expect(rows, hasLength(2));
    expect(calls, 2);
  });
}
