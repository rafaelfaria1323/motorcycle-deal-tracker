import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/saved_searches_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_cubit.dart';

class _FakeSearches implements SavedSearchesRepository {
  _FakeSearches(this.items, {this.failDelete = false});

  List<SavedSearch> items;
  final bool failDelete;

  @override
  Future<List<SavedSearch>> getAll() async => items;

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('not deleted');
    items = [
      for (final s in items)
        if (s.id != id) s,
    ];
  }

  @override
  Future<SavedSearch> create({
    required String name,
    required ListingFilters filters,
  }) => throw UnimplementedError();

  @override
  Future<SavedSearch> update(SavedSearch search) => throw UnimplementedError();
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
}
