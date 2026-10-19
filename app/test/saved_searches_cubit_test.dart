import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/saved_searches_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_state.dart';

class _FakeSearches implements SavedSearchesRepository {
  _FakeSearches(
    this.items, {
    this.failDelete = false,
    this.counts = const {},
    this.failCounts = false,
  });

  List<SavedSearch> items;
  final bool failDelete;
  final Map<String, int> counts;
  final bool failCounts;

  @override
  Future<List<SavedSearch>> getAll() async => items;

  @override
  Future<Map<String, int>> getMatchCounts() async {
    if (failCounts) throw StateError('counts failed');
    return counts;
  }

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('not deleted');
    items = [
      for (final s in items)
        if (s.id != id) s,
    ];
  }

  /// The database's defaults: alerts for new listings and price drops.
  @override
  Future<SavedSearch> create({
    required String name,
    required ListingFilters filters,
  }) async {
    final created = SavedSearch(
      id: 'new',
      name: name,
      filters: filters,
      createdAt: DateTime(2026, 10, 19),
    );
    items = [created, ...items];
    return created;
  }

  final updates = <SavedSearch>[];

  @override
  Future<SavedSearch> update(SavedSearch search) async {
    updates.add(search);
    items = [for (final s in items) s.id == search.id ? search : s];
    return search;
  }
}

/// Only the method the cubit uses; anything else would throw.
class _FakeListings implements ListingsRepository {
  @override
  Future<List<MotorcycleOption>> getMotorcycleOptions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SavedSearch _search(String id) => SavedSearch(
  id: id,
  name: 'Pesquisa $id',
  filters: const ListingFilters(minYear: 2026),
  createdAt: DateTime.utc(2026, 10, 18),
);

void main() {
  test('delete removes the search from the list', () async {
    final cubit = SavedSearchesCubit(
      _FakeSearches([_search('a'), _search('b')]),
      _FakeListings(),
    );
    await cubit.load();

    final deleted = await cubit.delete('a');

    expect(deleted, isTrue);
    expect(cubit.state.searches.map((s) => s.id), ['b']);
  });

  test('a failed delete keeps the list and reports failure', () async {
    final cubit = SavedSearchesCubit(
      _FakeSearches([_search('a')], failDelete: true),
      _FakeListings(),
    );
    await cubit.load();

    final deleted = await cubit.delete('a');

    expect(deleted, isFalse);
    expect(cubit.state.searches.map((s) => s.id), ['a']);
  });

  test('load brings the match counts', () async {
    final cubit = SavedSearchesCubit(
      _FakeSearches([_search('a'), _search('b')], counts: {'a': 3}),
      _FakeListings(),
    );

    await cubit.load();

    expect(cubit.state.matchCounts['a'], 3);
    expect(cubit.state.matchCounts['b'], isNull); // no matches
  });

  test('a failure loading the counts does not fail the list', () async {
    final cubit = SavedSearchesCubit(
      _FakeSearches([_search('a')], failCounts: true),
      _FakeListings(),
    );

    await cubit.load();

    expect(cubit.state.status, SavedSearchesStatus.success);
    expect(cubit.state.searches, hasLength(1));
    expect(cubit.state.matchCounts, isEmpty);
  });

  test('a new search keeps the alert choices made in its sheet', () async {
    final repository = _FakeSearches([_search('a')]);
    final cubit = SavedSearchesCubit(repository, _FakeListings());
    await cubit.load();

    final saved = await cubit.createFrom(
      SavedSearch.draft().copyWith(
        name: 'R7 até 8000 €',
        filters: const ListingFilters(maxPrice: 8000),
        notifyExcellentDeal: true,
      ),
    );

    expect(saved, isTrue);
    expect(cubit.state.searches.map((s) => s.id), ['new', 'a']);
    expect(cubit.state.searches.first.name, 'R7 até 8000 €');
    expect(cubit.state.searches.first.notifyExcellentDeal, isTrue);
    expect(repository.updates, hasLength(1));
  });

  test('a new search with the default alerts needs no second save', () async {
    final repository = _FakeSearches([]);
    final cubit = SavedSearchesCubit(repository, _FakeListings());
    await cubit.load();

    await cubit.createFrom(
      SavedSearch.draft().copyWith(
        name: 'MT-07',
        filters: const ListingFilters(minYear: 2024),
      ),
    );

    expect(cubit.state.searches.map((s) => s.id), ['new']);
    expect(repository.updates, isEmpty);
  });
}
