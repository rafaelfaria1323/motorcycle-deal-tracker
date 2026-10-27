import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';

const catalog = [
  MotorcycleOption(id: 'cb', brand: 'Honda', model: 'CB650R'),
  MotorcycleOption(id: 'cbr', brand: 'Honda', model: 'CBR650R'),
  MotorcycleOption(id: 'hornet', brand: 'Honda', model: 'CB750 Hornet'),
  MotorcycleOption(id: 'mt', brand: 'Yamaha', model: 'MT-07'),
];

void main() {
  test('the models are grouped by brand in the catalog order', () {
    final groups = modelsByBrand(catalog);
    expect(groups.keys, ['Honda', 'Yamaha']);
    expect(groups['Honda']!.map((m) => m.id), ['cb', 'cbr', 'hornet']);
  });

  test('the summary names each brand once', () {
    expect(modelsText(['cbr', 'cb'], catalog), 'Honda CB650R ou CBR650R');
    expect(modelsText(['mt', 'cb'], catalog), 'Honda CB650R ou Yamaha MT-07');
    expect(modelsText(['gone'], catalog), isEmpty);
    expect(
      summarizeFilters(
        const ListingFilters(motorcycleIds: ['cb', 'cbr'], minYear: 2022),
        catalog,
      ),
      'Honda CB650R ou CBR650R · desde 2022',
    );
  });

  test('each model is its own chip and removes only itself', () {
    const filters = ListingFilters(motorcycleIds: ['cb', 'cbr', 'gone']);
    final chips = filterChips(filters, catalog);

    expect(chips.map((c) => c.label), [
      'Honda CB650R',
      'Honda CBR650R',
      'Modelo',
    ]);
    expect(
      chips.first.without,
      const ListingFilters(motorcycleIds: ['cbr', 'gone']),
    );
    expect(filters.appliedCount, 1);
  });
}
