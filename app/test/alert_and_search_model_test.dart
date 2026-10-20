import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_alert_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';

Map<String, dynamic> _listing() => {
  'id': 'l1',
  'source': 'olx',
  'url': 'https://example.com/x',
  'brand': 'Honda',
  'model': 'CB650R',
  'seller_type': 'dealer',
  'status': 'active',
  'first_seen_at': '2026-10-18T19:00:00Z',
  'last_seen_at': '2026-10-19T08:00:00Z',
};

void main() {
  group('ListingAlertModel', () {
    Map<String, dynamic> row(String? type) => {
      'id': 'a1',
      'type': type,
      'created_at': '2026-10-19T08:00:00Z',
      'listings': _listing(),
    };

    test('reads the known types', () {
      expect(
        ListingAlertModel.fromJson(row('price_reduction')).type,
        AlertType.priceReduction,
      );
      expect(
        ListingAlertModel.fromJson(row('listing_removed')).type,
        AlertType.listingRemoved,
      );
      expect(
        ListingAlertModel.fromJson(row('back_on_market')).type,
        AlertType.backOnMarket,
      );
    });

    test('an unknown or missing type becomes unknown', () {
      expect(ListingAlertModel.fromJson(row('other')).type, AlertType.unknown);
      expect(ListingAlertModel.fromJson(row(null)).type, AlertType.unknown);
    });

    test('optional fields stay null when absent', () {
      final alert = ListingAlertModel.fromJson(row('new_listing'));
      expect(alert.searchName, isNull);
      expect(alert.oldPrice, isNull);
      expect(alert.readAt, isNull);
    });
  });

  group('SavedSearchModel', () {
    Map<String, dynamic> row(String? seller) => {
      'id': 's1',
      'created_at': '2026-10-19T08:00:00Z',
      'seller_type': seller,
    };

    test('reads the seller type', () {
      expect(
        SavedSearchModel.fromJson(row('dealer')).filters.sellerType,
        SellerType.dealer,
      );
    });

    test('a missing or unknown seller type means any (null)', () {
      expect(SavedSearchModel.fromJson(row(null)).filters.sellerType, isNull);
      expect(SavedSearchModel.fromJson(row('x')).filters.sellerType, isNull);
    });

    test('notification flags have defaults', () {
      final search = SavedSearchModel.fromJson(row(null));
      expect(search.notifyNewListing, isTrue);
      expect(search.notifyExcellentDeal, isFalse);
    });
  });
}
