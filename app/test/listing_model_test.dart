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
    expect(listing.hasFirstOwnerSignal, isFalse);
  });

  test(
    'summary queries fetch card facts without descriptions or full scores',
    () {
      final columns = ListingModel.summaryColumns
          .split(',')
          .map((column) => column.trim())
          .toSet();
      expect(
        columns,
        containsAll([
          'registrations',
          'service_book',
          'origin',
          'warranty_until',
          'dealer_warranty_months',
          'seller_name',
          'published_at',
          'site_refreshed_at',
          'card_risk_reasons:score_breakdown->risk_reasons',
        ]),
      );
      expect(columns, isNot(contains('description')));
      expect(columns, isNot(contains('score_breakdown')));
      expect(columns, isNot(contains('*')));

      final listing = ListingModel.fromJson(
        _row({
          'registrations': 1,
          'service_book': true,
          'origin': 'national',
          'warranty_until': '2027-03-01',
          'dealer_warranty_months': 18,
          'seller_name': 'Motos do Norte',
          'published_at': '2026-10-09T12:00:00Z',
          'site_refreshed_at': '2026-10-24T12:00:00Z',
        }),
      );
      expect(listing.registrations, 1);
      expect(listing.serviceBook, isTrue);
      expect(listing.origin, 'national');
      expect(listing.warrantyUntil, DateTime(2027, 3, 1));
      expect(listing.dealerWarrantyMonths, 18);
      expect(listing.sellerName, 'Motos do Norte');
      expect(listing.publishedAt, DateTime.utc(2026, 10, 9, 12));
      expect(listing.siteRefreshedAt, DateTime.utc(2026, 10, 24, 12));
    },
  );

  test('first-owner signals work in summary and detail responses', () {
    for (final fields in [
      {
        'card_risk_reasons': ['first_owner', 'service_book'],
      },
      {
        'score_breakdown': {
          'risk_reasons': ['first_owner'],
        },
      },
    ]) {
      expect(ListingModel.fromJson(_row(fields)).hasFirstOwnerSignal, isTrue);
    }
    final summary = ListingModel.fromJson(
      _row({
        'card_risk_reasons': ['first_owner'],
      }),
    );
    expect(summary.scoreBreakdown, isNull);
    expect(summary.description, isNull);
    expect(
      ListingModel.fromJson(
        _row({
          'card_risk_reasons': ['imported'],
        }),
      ).hasFirstOwnerSignal,
      isFalse,
    );
  });

  test('reads the colour and whether it is a favourite', () {
    final listing = ListingModel.fromJson(
      _row({'colour': 'blue', 'my_colour': true}),
    );
    expect(listing.colour, 'blue');
    expect(listing.myColour, isTrue);
    expect(ListingModel.fromJson(_row()).myColour, isFalse);
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
