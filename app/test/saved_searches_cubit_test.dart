import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/saved_searches_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_state.dart';

import 'helpers/session_fixture.dart';

late SessionFixture _session;

SavedSearchesCubit _cubit(SavedSearchesRepository repository) => _session.track(
  SavedSearchesCubit(repository, _FakeListings(), _session.cubit),
);

class _FakeSearches implements SavedSearchesRepository {
  _FakeSearches(
    this.items, {
    this.failDelete = false,
    this.counts = const {},
    this.failCounts = false,
  });

  List<SavedSearch> items;
  final bool failDelete;
  Map<String, int> counts;
  final bool failCounts;
  Future<List<SavedSearch>>? loadResult;
  Future<Map<String, int>>? countsResult;
  Future<SavedSearch>? createResult;
  Future<SavedSearch>? updateResult;
  Future<void>? deleteDelay;
  bool failLoad = false;
  int countsCalls = 0;

  @override
  Future<List<SavedSearch>> getAll() async {
    if (failLoad) throw StateError('offline');
    return loadResult ?? List.of(items);
  }

  @override
  Future<Map<String, int>> getMatchCounts() async {
    countsCalls++;
    if (failCounts) throw StateError('counts failed');
    return countsResult ?? counts;
  }

  @override
  Future<void> delete(String id) async {
    if (deleteDelay case final delay?) await delay;
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
    if (createResult case final response?) return response;
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
    if (updateResult case final response?) return response;
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
  setUp(() => _session = SessionFixture());

  test('delete removes the search from the list', () async {
    final cubit = _cubit(_FakeSearches([_search('a'), _search('b')]));
    await cubit.load();

    final deleted = await cubit.delete('a');

    expect(deleted, isTrue);
    expect(cubit.state.searches.map((s) => s.id), ['b']);
  });

  test('a failed delete keeps the list and reports failure', () async {
    final cubit = _cubit(_FakeSearches([_search('a')], failDelete: true));
    await cubit.load();

    final deleted = await cubit.delete('a');

    expect(deleted, isFalse);
    expect(cubit.state.searches.map((s) => s.id), ['a']);
  });

  test('load brings the match counts', () async {
    final cubit = _cubit(
      _FakeSearches([_search('a'), _search('b')], counts: {'a': 3}),
    );

    await cubit.load();

    expect(cubit.state.matchCounts['a'], 3);
    expect(cubit.state.matchCounts['b'], isNull); // no matches
  });

  test('a failure loading the counts does not fail the list', () async {
    final cubit = _cubit(_FakeSearches([_search('a')], failCounts: true));

    await cubit.load();

    expect(cubit.state.status, SavedSearchesStatus.success);
    expect(cubit.state.searches, hasLength(1));
    expect(cubit.state.matchCounts, isEmpty);
  });

  test('an older load cannot replace newer saved searches', () async {
    final response = Completer<List<SavedSearch>>();
    final repository = _FakeSearches([_search('current')])
      ..loadResult = response.future;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    final older = cubit.load();
    repository.loadResult = null;
    await cubit.load();

    response.complete([_search('old')]);
    await older;

    expect(cubit.state.searches.map((s) => s.id), ['current']);
  });

  test('an account change clears searches even when its load fails', () async {
    final response = Completer<List<SavedSearch>>();
    final repository = _FakeSearches(
      [_search('private')],
      counts: {'private': 3},
    );
    final cubit = _cubit(repository);
    await cubit.load();
    repository.loadResult = response.future;
    final older = cubit.load();
    repository.failLoad = true;

    await _session.changeAccount('other');

    expect(cubit.state.searches, isEmpty);
    expect(cubit.state.matchCounts, isEmpty);
    expect(cubit.state.status, SavedSearchesStatus.failure);
    response.complete([_search('private')]);
    await older;
    expect(cubit.state.searches, isEmpty);
    expect(cubit.state.status, SavedSearchesStatus.failure);
  });

  for (final method in ['create', 'createFrom', 'update', 'delete']) {
    test('a late $method cannot change another account', () async {
      final saved = Completer<SavedSearch>();
      final deleted = Completer<void>();
      final repository = _FakeSearches([_search('private')])
        ..createResult = saved.future
        ..updateResult = saved.future
        ..deleteDelay = deleted.future;
      final cubit = _cubit(repository);
      await cubit.load();
      final changing = switch (method) {
        'create' => cubit.create('Private', ListingFilters.empty),
        'createFrom' => cubit.createFrom(
          _search('private').copyWith(notifyExcellentDeal: true),
        ),
        'update' => cubit.update(_search('private')),
        _ => cubit.delete('private'),
      };
      repository.items = [_search('current')];
      await _session.changeAccount('other');
      final current = cubit.state;

      if (method == 'delete') {
        deleted.complete();
      } else {
        saved.complete(_search('private'));
      }

      expect(await changing, isFalse);
      expect(cubit.state, current);
      expect(cubit.state.searches.single.id, 'current');
      expect(repository.countsCalls, 2);
      expect(repository.updates, isEmpty);
    });
  }

  test('late match counts cannot overwrite a newer refresh', () async {
    final response = Completer<Map<String, int>>();
    final repository = _FakeSearches([_search('a')], counts: {'a': 1});
    final cubit = _cubit(repository);
    await cubit.load();
    repository.countsResult = response.future;
    final updating = cubit.update(_search('a'));
    await Future<void>.delayed(Duration.zero);
    repository
      ..countsResult = null
      ..counts = {'a': 7};
    await cubit.load();

    response.complete({'a': 2});
    expect(await updating, isTrue);
    expect(cubit.state.matchCounts, {'a': 7});
  });

  test('a pending load keeps counts refreshed by a later write', () async {
    final response = Completer<Map<String, int>>();
    final repository = _FakeSearches([_search('a')], counts: {'a': 1});
    final cubit = _cubit(repository);
    await cubit.load();
    repository.countsResult = response.future;
    final loading = cubit.load();
    repository
      ..countsResult = null
      ..counts = {'a': 7};
    expect(await cubit.update(_search('a')), isTrue);

    response.complete({'a': 2});
    await loading;

    expect(cubit.state.matchCounts, {'a': 7});
  });

  test('a late count refresh stays with its account', () async {
    final response = Completer<Map<String, int>>();
    final repository = _FakeSearches([_search('private')]);
    final cubit = _cubit(repository);
    await cubit.load();
    repository.countsResult = response.future;
    final updating = cubit.update(_search('private'));
    await Future<void>.delayed(Duration.zero);
    repository
      ..items = [_search('current')]
      ..countsResult = null
      ..counts = {'current': 7};
    await _session.changeAccount('other');

    response.complete({'private': 3});

    expect(await updating, isFalse);
    expect(cubit.state.matchCounts, {'current': 7});
  });

  for (final fails in [false, true]) {
    test(
      'a search load can ${fails ? 'fail' : 'finish'} after closing',
      () async {
        final response = Completer<List<SavedSearch>>();
        final repository = _FakeSearches([])..loadResult = response.future;
        final cubit = _cubit(repository);
        final loading = cubit.load();
        await cubit.close();

        if (fails) {
          response.completeError(StateError('offline'));
        } else {
          response.complete([_search('old')]);
        }
        await loading;

        expect(cubit.state.searches, isEmpty);
      },
    );
  }

  test('a new search keeps the alert choices made in its sheet', () async {
    final repository = _FakeSearches([_search('a')]);
    final cubit = _cubit(repository);
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
    final cubit = _cubit(repository);
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
