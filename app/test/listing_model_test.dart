import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';

Map<String, dynamic> _row([Map<String, dynamic> extra = const {}]) => {
  'id': 'l1',
  'source': 'olx',
  'url': 'https://example.com/x',
  'brand': 'Honda',
  'model': 'CB650R',
  'seller_type': 'private',
  'status': 'price_changed',
  'first_seen_at': '2026-10-18T19:00:00Z',
  'last_seen_at': '2026-10-19T08:00:00Z',
  ...extra,
};

void main() {
  test('reads a summary row, with whole numbers as prices', () {
    final listing = ListingModel.fromJson(_row({'price': 7400, 'year': 2021}));
    expect(listing.price, 7400.0);
    expect(listing.year, 2021);
    expect(listing.sellerType, SellerType.private);
    expect(listing.status, ListingStatus.priceChanged);
    expect(listing.images, isEmpty);
    expect(listing.firstSeenAt, DateTime.utc(2026, 10, 18, 19));
    expect(listing.lastSeenAt, DateTime.utc(2026, 10, 19, 8));
    expect(listing.description, isNull);
    expect(listing.newPrice, isNull);
  });

  test('unknown seller types and statuses fall back to unknown', () {
    final listing = ListingModel.fromJson(
      _row({'seller_type': 'bot', 'status': 'weird'}),
    );
    expect(listing.sellerType, SellerType.unknown);
    expect(listing.status, ListingStatus.unknown);
  });

  test('missing or malformed dates become null', () {
    final listing = ListingModel.fromJson(
      _row({
        'first_seen_at': null,
        'published_at': 'not a date',
        'warranty_until': '2027-03-01',
      }),
    );
    expect(listing.firstSeenAt, isNull);
    expect(listing.publishedAt, isNull);
    expect(listing.warrantyUntil, DateTime(2027, 3, 1));
  });

  test('takes the new-bike price from the embedded motorcycle', () {
    final listing = ListingModel.fromJson(
      _row({
        'motorcycles': {
          'new_price_reference': 8999,
          'new_price_checked_at': '2026-10-01T00:00:00Z',
        },
      }),
    );
    expect(listing.newPrice, 8999.0);
    expect(listing.newPriceCheckedAt, DateTime.utc(2026, 10));
  });

  test('reads the earlier ad of a relisted bike', () {
    final listing = ListingModel.fromJson(
      _row({
        'relisted_from': 'l0',
        'relisted_since': '2026-07-25T00:00:00Z',
        'relisted_price': 6500,
      }),
    );
    expect(listing.relistedFrom, 'l0');
    expect(listing.relistedSince, DateTime.utc(2026, 7, 25));
    expect(listing.relistedPrice, 6500.0);
  });
}
