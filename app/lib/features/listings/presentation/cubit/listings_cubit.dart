import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/first_page.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/repositories/listings_repository.dart';
import 'listings_state.dart';

class ListingsCubit extends Cubit<ListingsState> {
  ListingsCubit(this._repository) : super(const ListingsState());

  final ListingsRepository _repository;

  /// Listings per request; the list asks for more as it scrolls.
  static const pageSize = 40;

  /// Bumped by each [load]: an answer to an older one is dropped.
  var _generation = 0;

  /// Loads the first page (and the model list, the first time or when
  /// [models]: another account, or its models changed). [early]: the
  /// page `index.html` asked for before the app started, used instead of
  /// asking the database when it came and the filters and order are still
  /// the defaults it was asked with.
  Future<void> load({bool models = false, Future<FirstPage?>? early}) async {
    final generation = ++_generation;
    emit(state.copyWith(status: ListingsStatus.loading, loadingMore: false));
    final filters = state.filters;
    final sort = state.sort;
    try {
      final first =
          early != null &&
              filters == ListingFilters.empty &&
              sort == const ListingsState().sort
          ? await early
          : null;
      final (motorcycles, listings) = first != null
          ? (first.motorcycles, first.listings)
          : await (
              models || state.motorcycles.isEmpty
                  ? _repository.getMotorcycleOptions()
                  : Future.value(state.motorcycles),
              _repository.getListings(
                filters: filters,
                sort: sort,
                limit: pageSize,
              ),
            ).wait;
      // Filters changed or a reload started while loading: that newer
      // load wins.
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: ListingsStatus.success,
          listings: listings,
          motorcycles: motorcycles,
          hasMore: listings.length == pageSize,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      emit(state.copyWith(status: ListingsStatus.failure));
    }
  }

  /// Appends the next page; does nothing while one is loading or when
  /// there are no more.
  Future<void> loadMore() async {
    if (state.status != ListingsStatus.success ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    final generation = _generation;
    final filters = state.filters;
    final sort = state.sort;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getListings(
        filters: filters,
        sort: sort,
        offset: state.listings.length,
        limit: pageSize,
      );
      if (generation != _generation) return;
      emit(
        state.copyWith(
          listings: [...state.listings, ...page],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is shown; scrolling again retries.
      if (generation == _generation) emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> applySort(ListingSort sort) async {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    await load();
  }

  Future<void> applyFilters(ListingFilters filters) async {
    emit(state.copyWith(filters: filters));
    await load();
  }
}
