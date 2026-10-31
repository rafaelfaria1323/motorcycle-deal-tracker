import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/first_page.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/repositories/listings_repository.dart';
import 'listings_state.dart';

class ListingsCubit extends AccountScopedCubit<ListingsState> {
  ListingsCubit(
    this._repository,
    SessionCubit session, {
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(session, const ListingsState());

  final ListingsRepository _repository;
  final DateTime Function() _now;

  /// When the list shown was asked for; null before a load succeeded.
  DateTime? _loadedAt;

  /// How old the list must be before a return to the app counts the ads
  /// found since ([checkForNew]): the collection runs every 2 hours.
  static const staleAfter = Duration(minutes: 30);

  /// Listings per request; the list asks for more as it scrolls.
  static const pageSize = 40;

  /// Bumped by each [load]: an answer to an older one is dropped.
  var _generation = 0;

  @override
  void resetForAccount() {
    _loadedAt = null;
    emit(ListingsState(filters: state.filters, sort: state.sort));
  }

  /// Loads the first page (and the model list, the first time or when
  /// [models]: another account, or its models changed). [early]: the
  /// page `index.html` asked for before the app started, used instead of
  /// asking the database when it came and the filters and order are still
  /// the defaults it was asked with.
  @override
  Future<void> load({bool models = false, Future<FirstPage?>? early}) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_generation;
    final askedAt = _now();
    emit(
      state.copyWith(
        status: ListingsStatus.loading,
        loadingMore: false,
        newCount: 0,
      ),
    );
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
      if (!isCurrentAccount(account) || generation != _generation) return;
      _loadedAt = askedAt;
      emit(
        state.copyWith(
          status: ListingsStatus.success,
          listings: listings,
          motorcycles: motorcycles,
          hasMore: listings.length == pageSize,
        ),
      );
    } catch (_) {
      if (!isCurrentAccount(account) || generation != _generation) return;
      emit(state.copyWith(status: ListingsStatus.failure));
    }
  }

  /// Appends the next page; does nothing while one is loading or when
  /// there are no more.
  Future<void> loadMore() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account) ||
        state.status != .success ||
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
      if (!isCurrentAccount(account) || generation != _generation) return;
      emit(
        state.copyWith(
          listings: [...state.listings, ...page],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is shown; scrolling again retries.
      if (isCurrentAccount(account) && generation == _generation) {
        emit(state.copyWith(loadingMore: false));
      }
    }
  }

  /// On return to the app: counts the ads first seen since the list
  /// loaded, with its filters, once it is [staleAfter] old ("3 anúncios
  /// novos", tapped to reload). Quiet on failure: the list is still there.
  Future<void> checkForNew() async {
    final account = accountGeneration;
    final since = _loadedAt;
    if (!isCurrentAccount(account) ||
        state.status != .success ||
        since == null ||
        _now().difference(since) < staleAfter) {
      return;
    }
    final generation = _generation;
    try {
      final count = await _repository.countNewSince(
        since,
        filters: state.filters,
      );
      if (!isCurrentAccount(account) ||
          generation != _generation ||
          state.status != .success) {
        return;
      }
      emit(state.copyWith(newCount: count));
    } catch (_) {
      // Nothing to say: the next return asks again.
    }
  }

  Future<void> applySort(ListingSort sort) async {
    if (!isCurrentAccount(accountGeneration) || sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    await load();
  }

  Future<void> applyFilters(ListingFilters filters) async {
    if (!isCurrentAccount(accountGeneration)) return;
    emit(state.copyWith(filters: filters));
    await load();
  }
}
