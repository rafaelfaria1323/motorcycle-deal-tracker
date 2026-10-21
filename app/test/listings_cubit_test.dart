import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_state.dart';

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

  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) async {
    offsets.add(offset);
    sorts.add(sort);
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
  test('loads the first page, then the next ones until the last', () async {
    final repository = _PagedListings(ListingsCubit.pageSize * 2 + 5);
    final cubit = ListingsCubit(repository);

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
    final cubit = ListingsCubit(repository);
    await cubit.load();

    await Future.wait([cubit.loadMore(), cubit.loadMore()]);

    expect(repository.offsets, [0, 40]);
    expect(cubit.state.loadingMore, isFalse);
  });

  test('new filters start again from the first page', () async {
    final repository = _PagedListings(200);
    final cubit = ListingsCubit(repository);
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
    final cubit = ListingsCubit(repository);
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
    final cubit = ListingsCubit(repository);
    final older = cubit.load();
    await cubit.load();
    repository.first.complete([_listing(99)]);
    await older;

    expect(cubit.state.listings, hasLength(10));
  });

  test('models are read again when asked (another account)', () async {
    final repository = _PagedListings(5);
    final cubit = ListingsCubit(repository);
    await cubit.load();
    await cubit.load();
    expect(repository.optionCalls, 1);

    await cubit.load(models: true);
    expect(repository.optionCalls, 2);
  });
}
