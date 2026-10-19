import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/repositories/saved_searches_repository.dart';
import 'saved_searches_state.dart';

class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  SavedSearchesCubit(this._searches, this._listings)
    : super(const SavedSearchesState());

  final SavedSearchesRepository _searches;
  final ListingsRepository _listings;

  Future<void> load() async {
    emit(state.copyWith(status: SavedSearchesStatus.loading));
    try {
      final (searches, motorcycles, counts) = await (
        _searches.getAll(),
        _listings.getMotorcycleOptions(),
        // The counts are a nicety: if they fail, the list still shows.
        _searches.getMatchCounts().catchError((_) => const <String, int>{}),
      ).wait;
      emit(
        state.copyWith(
          status: SavedSearchesStatus.success,
          searches: searches,
          motorcycles: motorcycles,
          matchCounts: counts,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: SavedSearchesStatus.failure));
    }
  }

  Future<void> _refreshCounts() async {
    try {
      emit(state.copyWith(matchCounts: await _searches.getMatchCounts()));
    } catch (_) {
      // Keep the old counts.
    }
  }

  /// Returns true when the search was saved.
  Future<bool> create(String name, ListingFilters filters) async {
    try {
      final created = await _searches.create(name: name, filters: filters);
      emit(state.copyWith(searches: [created, ...state.searches]));
      await _refreshCounts();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves a search made in the "Nova pesquisa" sheet, with its alert
  /// choices. Returns true when it was saved; if only the alert choices
  /// fail to save, the search stays with the default ones.
  Future<bool> createFrom(SavedSearch draft) async {
    final SavedSearch created;
    try {
      created = await _searches.create(
        name: draft.name ?? '',
        filters: draft.filters,
      );
    } catch (_) {
      return false;
    }
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
      await _refreshCounts();
    }
    return true;
  }

  /// Returns true when the changes were saved.
  Future<bool> update(SavedSearch search) async {
    try {
      final updated = await _searches.update(search);
      emit(
        state.copyWith(
          searches: [
            for (final s in state.searches) s.id == updated.id ? updated : s,
          ],
        ),
      );
      await _refreshCounts();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the search was deleted.
  Future<bool> delete(String id) async {
    try {
      await _searches.delete(id);
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
