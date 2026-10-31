import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/first_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_state.dart';

import 'helpers/session_fixture.dart';

late SessionFixture _session;

ListingsCubit _cubit(ListingsRepository repository) =>
    _session.track(ListingsCubit(repository, _session.cubit));

Listing _listing(int n) => Listing(
  id: 'l$n',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/$n.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
);

/// Serves [total] listings in pages, like the database does.
class _PagedListings implements ListingsRepository {
  _PagedListings(this.total);

  final int total;
  final offsets = <int>[];
  final sorts = <ListingSort>[];
  var optionCalls = 0;
  Future<List<Listing>>? result;
  bool failLoad = false;

  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) async {
    offsets.add(offset);
    sorts.add(sort);
    if (failLoad) throw StateError('offline');
    if (result case final response?) return await response;
    final end = (offset + limit).clamp(0, total);
    return [for (var i = offset; i < end; i++) _listing(i)];
  }

  @override
  Future<List<MotorcycleOption>> getMotorcycleOptions() async {
    optionCalls++;
    return const [MotorcycleOption(id: 'm', brand: 'Yamaha', model: 'MT-07')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The first request waits for [first]; later ones answer at once.
class _SlowFirst extends _PagedListings {
  _SlowFirst() : super(10);

  final first = Completer<List<Listing>>();
  var calls = 0;

  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) => calls++ == 0
      ? first.future
      : super.getListings(
          filters: filters,
          sort: sort,
          offset: offset,
          limit: limit,
        );
}

void main() {
  setUp(() => _session = SessionFixture());

  test('loads the first page, then the next ones until the last', () async {
    final repository = _PagedListings(ListingsCubit.pageSize * 2 + 5);
    final cubit = _cubit(repository);

    await cubit.load();
    expect(cubit.state.listings, hasLength(ListingsCubit.pageSize));
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();
    await cubit.loadMore();
    expect(cubit.state.listings, hasLength(ListingsCubit.pageSize * 2 + 5));
    expect(cubit.state.hasMore, isFalse);
    expect(cubit.state.listings.map((l) => l.id).toSet(), hasLength(85));

    await cubit.loadMore();
    expect(repository.offsets, [0, 40, 80]);
  });

  test('asks for the next page only once while it loads', () async {
    final repository = _PagedListings(200);
    final cubit = _cubit(repository);
    await cubit.load();

    await Future.wait([cubit.loadMore(), cubit.loadMore()]);

    expect(repository.offsets, [0, 40]);
    expect(cubit.state.loadingMore, isFalse);
  });

  test('new filters start again from the first page', () async {
    final repository = _PagedListings(200);
    final cubit = _cubit(repository);
    await cubit.load();
    await cubit.loadMore();

    await cubit.applyFilters(const ListingFilters(maxPrice: 7000));

    expect(cubit.state.status, ListingsStatus.success);
    expect(cubit.state.listings, hasLength(ListingsCubit.pageSize));
    expect(repository.offsets.last, 0);
    expect(repository.optionCalls, 1);
  });

  test('a new sort order starts again from the first page', () async {
    final repository = _PagedListings(200);
    final cubit = _cubit(repository);
    await cubit.load();
    await cubit.loadMore();

    await cubit.applySort(ListingSort.priceAsc);

    expect(cubit.state.sort, ListingSort.priceAsc);
    expect(cubit.state.listings, hasLength(ListingsCubit.pageSize));
    expect(repository.sorts.last, ListingSort.priceAsc);
    expect(repository.offsets.last, 0);
  });

  test('an older answer never replaces a newer load', () async {
    final repository = _SlowFirst();
    final cubit = _cubit(repository);
    final older = cubit.load();
    await cubit.load();
    repository.first.complete([_listing(99)]);
    await older;

    expect(cubit.state.listings, hasLength(10));
  });

  test('models are read again when asked (another account)', () async {
    final repository = _PagedListings(5);
    final cubit = _cubit(repository);
    await cubit.load();
    await cubit.load();
    expect(repository.optionCalls, 1);

    await cubit.load(models: true);
    expect(repository.optionCalls, 2);
  });

  test('an account change clears listings and models even offline', () async {
    final repository = _PagedListings(5);
    final cubit = _cubit(repository);
    await cubit.load();
    repository.failLoad = true;

    await _session.changeAccount('other');

    expect(cubit.state.listings, isEmpty);
    expect(cubit.state.motorcycles, isEmpty);
    expect(cubit.state.status, ListingsStatus.failure);
    expect(cubit.state.hasMore, isFalse);
  });

  test(
    'an account reload preserves filters and order, not cached models',
    () async {
      final repository = _PagedListings(5);
      final cubit = _cubit(repository);
      const filters = ListingFilters(maxPrice: 7000);
      await cubit.applyFilters(filters);
      await cubit.applySort(ListingSort.priceAsc);
      final response = Completer<List<Listing>>();
      repository.result = response.future;

      await _session.changeAccount('other');

      expect(cubit.state.listings, isEmpty);
      expect(cubit.state.motorcycles, isEmpty);
      expect(cubit.state.filters, filters);
      expect(cubit.state.sort, ListingSort.priceAsc);
      expect(repository.optionCalls, 2);
      final loaded = cubit.stream.firstWhere(
        (state) => state.status == ListingsStatus.success,
      );
      response.complete([_listing(99)]);
      await loaded;
    },
  );

  for (final more in [false, true]) {
    test(
      'an old ${more ? 'next' : 'first'} page stays in its account',
      () async {
        final repository = _PagedListings(80);
        final cubit = _cubit(repository);
        if (more) await cubit.load();
        final response = Completer<List<Listing>>();
        repository.result = response.future;
        final older = more ? cubit.loadMore() : cubit.load();
        repository
          ..result = null
          ..failLoad = true;

        await _session.changeAccount('other');
        response.complete([_listing(99)]);
        await older;

        expect(cubit.state.listings, isEmpty);
        expect(cubit.state.motorcycles, isEmpty);
        expect(cubit.state.status, ListingsStatus.failure);
        expect(cubit.state.loadingMore, isFalse);
      },
    );

    test(
      'a ${more ? 'next' : 'first'} page can finish after closing',
      () async {
        final repository = _PagedListings(80);
        final cubit = _cubit(repository);
        if (more) await cubit.load();
        final response = Completer<List<Listing>>();
        repository.result = response.future;
        final loading = more ? cubit.loadMore() : cubit.load();
        await cubit.close();
        final closed = cubit.state;

        response.complete([_listing(99)]);
        await loading;

        expect(cubit.state, closed);
      },
    );
  }

  group('the page index.html asked for early', () {
    final early = FirstPage(
      listings: [for (var i = 0; i < ListingsCubit.pageSize; i++) _listing(i)],
      motorcycles: const [
        MotorcycleOption(id: 'r7', brand: 'Yamaha', model: 'R7'),
      ],
    );

    test('is shown without asking the database', () async {
      final repository = _PagedListings(200);
      final cubit = _cubit(repository);

      await cubit.load(early: Future.value(early));

      expect(cubit.state.status, ListingsStatus.success);
      expect(cubit.state.listings, early.listings);
      expect(cubit.state.motorcycles, early.motorcycles);
      expect(cubit.state.hasMore, isTrue);
      expect(repository.offsets, isEmpty);
      expect(repository.optionCalls, 0);

      await cubit.loadMore();
      expect(repository.offsets, [ListingsCubit.pageSize]);
    });

    test('missing, the app asks itself', () async {
      final repository = _PagedListings(5);
      final cubit = _cubit(repository);

      await cubit.load(early: Future.value());

      expect(cubit.state.listings, hasLength(5));
      expect(repository.offsets, [0]);
      expect(repository.optionCalls, 1);
    });

    test('is not used once the filters changed', () async {
      final repository = _PagedListings(5);
      final cubit = _cubit(repository);
      await cubit.applyFilters(const ListingFilters(maxPrice: 7000));

      await cubit.load(early: Future.value(early));

      expect(cubit.state.listings, hasLength(5));
      expect(repository.offsets, [0, 0]);
    });

    test('a public prefetch cannot replace a signed-in account', () async {
      await _session.changeAccount(null);
      final repository = _PagedListings(5);
      final cubit = _cubit(repository);
      final response = Completer<FirstPage?>();
      final loading = cubit.load(early: response.future);

      await _session.changeAccount('other');
      response.complete(early);
      await loading;

      expect(cubit.state.listings, hasLength(5));
      expect(cubit.state.motorcycles.single.id, 'm');
    });
  });
}
