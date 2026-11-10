import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
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
      'max_year': 2028,
      'min_price': 4000,
      'max_price': 8000,
      'max_mileage': null,
      'district': 'Porto',
      'seller_type': null,
      'created_at': '2026-10-18T12:00:00Z',
    });
    expect(
      search.filters,
      const ListingFilters(
        motorcycleIds: ['m1'],
        minYear: 2026,
        maxYear: 2028,
        minPrice: 4000,
        maxPrice: 8000,
        district: 'Porto',
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

  test('the year and price ranges and the district read as criteria', () {
    const filters = ListingFilters(
      minYear: 2018,
      maxYear: 2020,
      minPrice: 4000,
      maxPrice: 6000,
      district: 'Porto',
    );
    expect(filters.hasCriteria, isTrue);
    expect(filters.appliedCount, 5);
    expect(
      summarizeFilters(filters, const []),
      'desde 2018 · até 2020 · desde ${Formatters.price(4000)} · '
      'até ${Formatters.price(6000)} · Porto',
    );
    final chips = filterChips(filters, const []);
    expect(chips.map((c) => c.label), [
      'desde 2018',
      'até 2020',
      'desde ${Formatters.price(4000)}',
      'até ${Formatters.price(6000)}',
      'Porto',
    ]);
    expect(chips[1].without.maxYear, isNull);
    expect(chips[1].without.minYear, 2018);
    expect(chips[2].without.minPrice, isNull);
    expect(chips[2].without.maxPrice, 6000);
    expect(chips[4].without.district, isNull);
    expect(const ListingFilters(maxYear: 2020).hasCriteria, isTrue);
    expect(const ListingFilters(minPrice: 1).hasCriteria, isTrue);
    expect(const ListingFilters(district: 'Faro').hasCriteria, isTrue);
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
    }).copyWith(filters: const ListingFilters(district: 'Porto'));

    final row = SavedSearchModel.toUpdate(search);

    expect(row['district'], 'Porto');
    expect(row.containsKey('max_year'), isTrue);
    expect(row['min_price'], isNull);
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

  group('card criteria', () {
    const motorcycles = [
      MotorcycleOption(id: 'mt', brand: 'Yamaha', model: 'MT-07'),
      MotorcycleOption(id: 'cb', brand: 'Honda', model: 'CB650R'),
    ];

    test('name each criterion and join a range', () {
      final criteria = searchCriteria(
        const ListingFilters(
          motorcycleIds: ['mt', 'cb'],
          minYear: 2020,
          maxYear: 2023,
          maxPrice: 7500,
          maxMileage: 25000,
          district: 'Porto',
          sellerType: SellerType.private,
          minDealScore: 80,
          maxRiskScore: 19,
          maxDistanceKm: 50,
          extras: ['quickshifter', 'luggage'],
          onlyMyColours: true,
        ),
        motorcycles,
      );

      expect(criteria.map((c) => (c.label, c.value)), [
        ('Modelos', 'Yamaha MT-07 ou Honda CB650R'),
        ('Ano', 'De 2020 a 2023'),
        ('Preço', 'até ${Formatters.price(7500)}'),
        ('Quilometragem', 'até ${Formatters.mileage(25000)}'),
        ('Distrito', 'Porto'),
        ('Vendedor', 'Particular'),
        ('Deal Score', 'Muito bom (80+)'),
        ('Risco', 'Risco baixo'),
        ('Distância', 'até ${Formatters.mileage(50)} de casa'),
        ('Equipamento', 'quickshifter, malas'),
        ('Cor', 'As suas cores'),
      ]);
      expect(criteria.where((c) => c.positive).map((c) => c.label), [
        'Deal Score',
      ]);
    });

    test('an open range says from or up to', () {
      String? value(ListingFilters filters, String label) => searchCriteria(
        filters,
        const [],
      ).where((c) => c.label == label).firstOrNull?.value;

      expect(value(const ListingFilters(minYear: 2020), 'Ano'), 'desde 2020');
      expect(value(const ListingFilters(maxYear: 2023), 'Ano'), 'até 2023');
      expect(
        value(const ListingFilters(minPrice: 4000, maxPrice: 5800), 'Preço'),
        'De ${Formatters.price(4000)} a ${Formatters.price(5800)}',
      );
      expect(
        value(const ListingFilters(minPrice: 4000), 'Preço'),
        'desde ${Formatters.price(4000)}',
      );
      expect(searchCriteria(ListingFilters.empty, const []), isEmpty);
    });

    test('in English', () {
      final criteria = searchCriteria(
        const ListingFilters(minYear: 2020, onlyMyColours: true),
        const [],
        language: AppLanguage.english,
      );
      expect(criteria.map((c) => (c.label, c.value)), [
        ('Year', 'from 2020'),
        ('Colour', 'Your colours'),
      ]);
    });

    test('the card says when the search was made', () {
      final search = SavedSearch(
        id: 's1',
        filters: ListingFilters.empty,
        createdAt: DateTime(2026, 11, 1, 12),
      );
      expect(
        searchCreatedText(search, now: DateTime(2026, 11, 1, 18)),
        'Criada hoje',
      );
      expect(
        searchCreatedText(search, now: DateTime(2026, 11, 4, 12)),
        'Criada há 3 dias',
      );
      expect(
        searchCreatedText(
          search,
          now: DateTime(2026, 11, 2, 12),
          language: AppLanguage.english,
        ),
        'Created yesterday',
      );
    });
  });
}
