import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

void main() {
  test('the filter offers the equipment the database detects', () {
    expect(extraLabels.keys, [
      'quickshifter',
      'exhaust',
      'luggage',
      'heated_grips',
      'protection',
      'new_tyres',
      'tail_tidy',
      'screen',
      'levers',
      'mirrors',
      'phone_mount',
      'alarm',
      'steering_damper',
      'centre_stand',
      'cruise_control',
      'suspension',
      'led_indicators',
      'passenger_grips',
      'original_parts',
    ]);
  });

  test('counts once as a filter and is a saved-search criterion', () {
    const filters = ListingFilters(extras: ['quickshifter', 'luggage']);
    expect(filters.appliedCount, 1);
    expect(filters.hasCriteria, isTrue);
    expect(filters.criteriaOnly.extras, ['quickshifter', 'luggage']);
    expect(ListingFilters.empty.hasCriteria, isFalse);
  });

  test('one chip per extra, each removing only itself', () {
    const filters = ListingFilters(extras: ['quickshifter', 'luggage']);
    final chips = filterChips(filters, const []);
    expect(chips.map((c) => c.label), ['com quickshifter', 'com malas']);
    expect(chips.first.without, const ListingFilters(extras: ['luggage']));
    expect(summarizeFilters(filters, const []), 'com quickshifter · com malas');
  });

  test('saved with the search and read back', () {
    expect(
      SavedSearchModel.toInsert(
        'QS',
        const ListingFilters(extras: ['quickshifter']),
      )['extras'],
      ['quickshifter'],
    );
    final row = {'id': 's1', 'created_at': '2026-10-19T08:00:00Z'};
    expect(
      SavedSearchModel.fromJson({
        ...row,
        'extras': ['exhaust'],
      }).filters.extras,
      ['exhaust'],
    );
    expect(SavedSearchModel.fromJson(row).filters.extras, isEmpty);
  });
}
