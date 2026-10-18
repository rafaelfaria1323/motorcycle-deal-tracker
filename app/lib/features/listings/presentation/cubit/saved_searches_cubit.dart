import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/listing_filters.dart';
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
      final (searches, motorcycles) = await (
        _searches.getAll(),
        _listings.getMotorcycleOptions(),
      ).wait;
      emit(
        state.copyWith(
          status: SavedSearchesStatus.success,
          searches: searches,
          motorcycles: motorcycles,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: SavedSearchesStatus.failure));
    }
  }

  /// Returns true when the search was saved.
  Future<bool> create(String name, ListingFilters filters) async {
    try {
      final created = await _searches.create(name: name, filters: filters);
      emit(state.copyWith(searches: [created, ...state.searches]));
      return true;
    } catch (_) {
      return false;
    }
  }
}
