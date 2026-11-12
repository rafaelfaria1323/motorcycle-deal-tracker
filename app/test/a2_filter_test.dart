import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/presentation/saved_search_summary.dart';

void main() {
  test('counts as a filter and a saved-search criterion', () {
    const filters = ListingFilters(a2: A2Fit.ready);
    expect(filters.appliedCount, 1);
    expect(filters.hasCriteria, isTrue);
    expect(filters.criteriaOnly.a2, A2Fit.ready);
    expect(ListingFilters.empty.a2, isNull);
    expect(filters, isNot(const ListingFilters(a2: A2Fit.restrictable)));
  });

  test('summary, chip and criterion', () {
    const filters = ListingFilters(minYear: 2024, a2: A2Fit.restrictable);
    expect(
      summarizeFilters(filters, const []),
      'desde 2024 · para carta A2 (ou limitável)',
    );
    final chip = filterChips(filters, const []).last;
    expect(chip.label, 'para carta A2 (ou limitável)');
    expect(chip.without, const ListingFilters(minYear: 2024));
    expect(
      filterChips(filters, const []).first.without,
      const ListingFilters(a2: A2Fit.restrictable),
    );
    expect(searchCriteria(const ListingFilters(a2: A2Fit.ready), const []), [
      (label: 'Carta A2', value: 'Pronta para A2', positive: false),
    ]);
    expect(
      a2Label(A2Fit.ready, language: AppLanguage.english),
      'for an A2 licence',
    );
    expect(
      a2OptionLabel(A2Fit.restrictable, language: AppLanguage.english),
      'A2-ready or restrictable to 35 kW',
    );
  });

  test('saved with the search and read back', () {
    expect(
      SavedSearchModel.toInsert(
        'A2',
        const ListingFilters(a2: A2Fit.restrictable),
      )['a2'],
      'restrictable',
    );
    expect(
      SavedSearchModel.toInsert('Todas', ListingFilters.empty),
      containsPair('a2', null),
    );
    final row = {
      'id': 's1',
      'created_at': '2026-11-12T12:00:00Z',
      'a2': 'ready',
    };
    expect(SavedSearchModel.fromJson(row).filters.a2, A2Fit.ready);
    expect(
      SavedSearchModel.fromJson({...row, 'a2': 'a1'}).filters.a2,
      isNull,
      reason: 'an unknown value is no criterion',
    );
    expect(
      SavedSearchModel.fromJson({...row}..remove('a2')).filters.a2,
      isNull,
    );
  });
}
