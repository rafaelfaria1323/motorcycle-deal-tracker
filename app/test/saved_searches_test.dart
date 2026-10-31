import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/presentation/saved_search_summary.dart';

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
        motorcycleIds: ['m1'],
        minYear: 2026,
        maxPrice: 8000,
        sellerType: SellerType.dealer,
      ),
    );
    expect(row['name'], 'MT-07 barata');
    expect(row['motorcycle_ids'], ['m1']);
    expect(row['max_price'], 8000);
    expect(row['seller_type'], 'dealer');
    expect(row.containsKey('user_id'), isFalse);
  });

  test('a stored row becomes the same filters again', () {
    final search = SavedSearchModel.fromJson({
      'id': 's1',
      'name': 'Teste',
      'motorcycle_ids': ['m1'],
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
        motorcycleIds: ['m1'],
        minYear: 2026,
        maxPrice: 8000,
        location: 'Porto',
      ),
    );
    expect(savedSearchName(search), 'Teste');
  });

  test('only an unnamed search needs a translated display name', () {
    final search = SavedSearch.draft();
    expect(savedSearchName(search), 'Pesquisa sem nome');
    expect(
      savedSearchName(search, language: AppLanguage.english),
      'Unnamed search',
    );
    expect(
      savedSearchName(
        search.copyWith(name: '  '),
        language: AppLanguage.english,
      ),
      'Unnamed search',
    );
    expect(
      savedSearchName(
        search.copyWith(name: 'A minha pesquisa'),
        language: AppLanguage.english,
      ),
      'A minha pesquisa',
    );
  });

  test('the summary names the model and the criteria', () {
    final text = summarizeFilters(
      const ListingFilters(motorcycleIds: ['m1'], minYear: 2026),
      const [MotorcycleOption(id: 'm1', brand: 'Yamaha', model: 'MT-07')],
    );
    expect(text, contains('Yamaha MT-07'));
    expect(text, contains('desde 2026'));
  });

  test('copyWith changes only what it is given', () {
    final search = SavedSearchModel.fromJson({
      'id': 's1',
      'name': 'Teste',
      'motorcycle_ids': ['m1'],
      'min_year': 2026,
      'created_at': '2026-10-18T12:00:00Z',
    });
    final edited = search.copyWith(
      name: 'Novo nome',
      notifyExcellentDeal: true,
    );

    expect(edited.id, 's1');
    expect(edited.name, 'Novo nome');
    expect(edited.filters, search.filters);
    expect(edited.notifyExcellentDeal, isTrue);
    expect(edited.notifyNewListing, search.notifyNewListing);
  });

  test('the update row sends cleared criteria as explicit nulls', () {
    final search = SavedSearchModel.fromJson({
      'id': 's1',
      'name': 'Teste',
      'created_at': '2026-10-18T12:00:00Z',
    }).copyWith(filters: const ListingFilters(location: 'Porto'));

    final row = SavedSearchModel.toUpdate(search);

    expect(row['location'], 'Porto');
    expect(row.containsKey('min_year'), isTrue);
    expect(row['min_year'], isNull);
    expect(row['notify_price_reduction'], isTrue);
    expect(row.containsKey('user_id'), isFalse);
    expect(row.containsKey('id'), isFalse);
  });

  test('criteriaOnly drops the live-only switch', () {
    const filters = ListingFilters(minYear: 2026, activeOnly: false);
    expect(filters.criteriaOnly.activeOnly, isTrue);
    expect(filters.criteriaOnly.minYear, 2026);
  });

  group('score criteria', () {
    test('count as criteria and survive a save', () {
      const filters = ListingFilters(minDealScore: 80, maxRiskScore: 19);
      expect(filters.hasCriteria, isTrue);
      expect(filters.appliedCount, 2);

      final row = SavedSearchModel.toInsert('Boas', filters);
      expect(row['min_deal_score'], 80);
      expect(row['max_risk_score'], 19);

      final back = SavedSearchModel.fromJson({
        'id': 's1',
        'name': 'Boas',
        ...row,
        'created_at': '2026-10-19T12:00:00Z',
      });
      expect(back.filters, filters);
      expect(back.filters.criteriaOnly, filters);
    });

    test('are named in the summary', () {
      final text = summarizeFilters(
        const ListingFilters(minDealScore: 80, maxRiskScore: 49),
        const [],
      );

      expect(text, 'Deal Score 80+ · Risco até médio');
    });
  });
}
