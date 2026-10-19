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
}
