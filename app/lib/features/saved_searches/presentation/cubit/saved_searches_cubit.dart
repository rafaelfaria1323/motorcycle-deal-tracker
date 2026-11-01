import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../listings/domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';
import '../../../listings/domain/repositories/listings_repository.dart';
import '../../domain/repositories/saved_searches_repository.dart';
import 'saved_searches_state.dart';

class SavedSearchesCubit extends AccountScopedCubit<SavedSearchesState> {
  SavedSearchesCubit(this._searches, this._listings, SessionCubit session)
    : super(session, const SavedSearchesState());

  final SavedSearchesRepository _searches;
  final ListingsRepository _listings;
  int _loadGeneration = 0;
  int _countsGeneration = 0;

  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_loadGeneration;
    final countsGeneration = ++_countsGeneration;
    emit(state.copyWith(status: SavedSearchesStatus.loading));
    try {
      final (searches, motorcycles, counts) = await (
        _searches.getAll(),
        _listings.getMotorcycleOptions(),
        // The counts are a nicety: if they fail, the list still shows.
        _searches.getMatchCounts().catchError((_) => const <String, int>{}),
      ).wait;
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: SavedSearchesStatus.success,
          searches: searches,
          motorcycles: motorcycles,
          matchCounts: countsGeneration == _countsGeneration
              ? counts
              : state.matchCounts,
        ),
      );
    } catch (_) {
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      emit(state.copyWith(status: SavedSearchesStatus.failure));
    }
  }

  Future<void> _refreshCounts(int account) async {
    if (!isCurrentAccount(account)) return;
    final generation = ++_countsGeneration;
    try {
      final counts = await _searches.getMatchCounts();
      if (!isCurrentAccount(account) || generation != _countsGeneration) return;
      emit(state.copyWith(matchCounts: counts));
    } catch (_) {
      // Keep the old counts.
    }
  }

  /// Returns true when the search was saved.
  Future<bool> create(String name, ListingFilters filters) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    try {
      final created = await _searches.create(name: name, filters: filters);
      if (!isCurrentAccount(account)) return false;
      emit(state.copyWith(searches: [created, ...state.searches]));
      await _refreshCounts(account);
      return isCurrentAccount(account);
    } catch (_) {
      return false;
    }
  }

  /// Saves a search made in the "Nova pesquisa" sheet, with its alert
  /// choices. Returns true when it was saved; if only the alert choices
  /// fail to save, the search stays with the default ones.
  Future<bool> createFrom(SavedSearch draft) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    final SavedSearch created;
    try {
      created = await _searches.create(
        name: draft.name ?? '',
        filters: draft.filters,
      );
    } catch (_) {
      return false;
    }
    if (!isCurrentAccount(account)) return false;
    emit(state.copyWith(searches: [created, ...state.searches]));

    final wanted = created.copyWith(
      notifyNewListing: draft.notifyNewListing,
      notifyPriceReduction: draft.notifyPriceReduction,
      notifyExcellentDeal: draft.notifyExcellentDeal,
      notifyListingRemoved: draft.notifyListingRemoved,
    );
    if (wanted != created) {
      await update(wanted);
    } else {
      await _refreshCounts(account);
    }
    return isCurrentAccount(account);
  }

  /// Returns true when the changes were saved.
  Future<bool> update(SavedSearch search) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    try {
      final updated = await _searches.update(search);
      if (!isCurrentAccount(account)) return false;
      emit(
        state.copyWith(
          searches: [
            for (final s in state.searches) s.id == updated.id ? updated : s,
          ],
        ),
      );
      await _refreshCounts(account);
      return isCurrentAccount(account);
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the search was deleted.
  Future<bool> delete(String id) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    try {
      await _searches.delete(id);
      if (!isCurrentAccount(account)) return false;
      emit(
        state.copyWith(
          searches: [
            for (final s in state.searches)
              if (s.id != id) s,
          ],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
