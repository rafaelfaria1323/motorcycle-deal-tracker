import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';

void main() {
  test('hasCriteria ignores the live-only switch', () {
    expect(ListingFilters.empty.hasCriteria, isFalse);
    expect(const ListingFilters(activeOnly: false).hasCriteria, isFalse);
    expect(const ListingFilters(minYear: 2026).hasCriteria, isTrue);
  });

  test('the insert row carries the criteria and no user id', () {
    final row = SavedSearchModel.toInsert(
      'MT-07 barata',
      const ListingFilters(
        motorcycleId: 'm1',
        minYear: 2026,
        maxPrice: 8000,
        sellerType: SellerType.dealer,
      ),
    );
    expect(row['name'], 'MT-07 barata');
    expect(row['motorcycle_id'], 'm1');
    expect(row['max_price'], 8000);
    expect(row['seller_type'], 'dealer');
    expect(row.containsKey('user_id'), isFalse);
  });

  test('a stored row becomes the same filters again', () {
    final search = SavedSearchModel.fromJson({
      'id': 's1',
      'name': 'Teste',
      'motorcycle_id': 'm1',
      'min_year': 2026,
      'max_price': 8000,
      'max_mileage': null,
      'location': 'Porto',
      'seller_type': null,
      'created_at': '2026-10-18T12:00:00Z',
    });
    expect(
      search.filters,
      const ListingFilters(
        motorcycleId: 'm1',
        minYear: 2026,
        maxPrice: 8000,
        location: 'Porto',
      ),
    );
    expect(search.displayName, 'Teste');
  });

  test('the summary names the model and the criteria', () {
    final text = summarizeFilters(
      const ListingFilters(motorcycleId: 'm1', minYear: 2026),
      const [MotorcycleOption(id: 'm1', brand: 'Yamaha', model: 'MT-07')],
    );
    expect(text, contains('Yamaha MT-07'));
    expect(text, contains('desde 2026'));
  });
}
