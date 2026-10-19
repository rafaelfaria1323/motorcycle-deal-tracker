import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/listing_filters.dart';
import '../../domain/repositories/listings_repository.dart';
import 'listings_state.dart';

class ListingsCubit extends Cubit<ListingsState> {
  ListingsCubit(this._repository) : super(const ListingsState());

  final ListingsRepository _repository;

  /// Listings per request; the list asks for more as it scrolls.
  static const pageSize = 40;

  /// Loads the first page (and the model list, the first time).
  Future<void> load() async {
    emit(state.copyWith(status: ListingsStatus.loading, loadingMore: false));
    final filters = state.filters;
    final sort = state.sort;
    try {
      final (motorcycles, listings) = await (
        state.motorcycles.isEmpty
            ? _repository.getMotorcycleOptions()
            : Future.value(state.motorcycles),
        _repository.getListings(filters: filters, sort: sort, limit: pageSize),
      ).wait;
      // Filters changed while loading: that newer load wins.
      if (state.filters != filters || state.sort != sort) return;
      emit(
        state.copyWith(
          status: ListingsStatus.success,
          listings: listings,
          motorcycles: motorcycles,
          hasMore: listings.length == pageSize,
        ),
      );
    } catch (_) {
      if (state.filters != filters || state.sort != sort) return;
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
      if (state.filters != filters ||
          state.sort != sort ||
          state.status != ListingsStatus.success) {
        return;
      }
      emit(
        state.copyWith(
          listings: [...state.listings, ...page],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is shown; scrolling again retries.
      if (state.filters == filters && state.sort == sort) {
        emit(state.copyWith(loadingMore: false));
      }
    }
  }

  Future<void> applyFilters(ListingFilters filters) async {
    emit(state.copyWith(filters: filters));
    await load();
  }
}
