import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_labels.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';

const mt07 = MotorcycleOption(id: 'mt', brand: 'Yamaha', model: 'MT-07');

void main() {
  test('no filters, no chips', () {
    expect(filterChips(ListingFilters.empty, const [mt07]), isEmpty);
  });

  test('each chip removes only its own filter', () {
    const filters = ListingFilters(
      motorcycleIds: ['mt'],
      maxPrice: 7500,
      sellerType: SellerType.private,
      activeOnly: false,
    );

    final chips = filterChips(filters, const [mt07]);

    expect(chips.map((c) => c.label), [
      'Yamaha MT-07',
      'até ${Formatters.price(7500)}',
      SellerType.private.label,
      'Inclui removidos',
    ]);
    expect(
      chips[1].without,
      const ListingFilters(
        motorcycleIds: ['mt'],
        sellerType: SellerType.private,
        activeOnly: false,
      ),
    );
    expect(chips.last.without.activeOnly, isTrue);
    expect(chips.last.without.maxPrice, 7500);
  });

  test('every sort order has a label', () {
    expect(ListingSort.values.map((s) => s.label).toSet(), hasLength(5));
    expect(ListingSort.dealScoreDesc.label, 'Melhor pontuação');
  });
}
