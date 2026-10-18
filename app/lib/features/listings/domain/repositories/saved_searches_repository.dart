import '../entities/listing_filters.dart';
import '../entities/saved_search.dart';

abstract interface class SavedSearchesRepository {
  /// Saves the filters as a search for the current user.
  Future<SavedSearch> create({
    required String name,
    required ListingFilters filters,
  });

  /// The current user's searches, newest first.
  Future<List<SavedSearch>> getAll();

  /// Saves the name, criteria and notification choices of [search].
  Future<SavedSearch> update(SavedSearch search);

  /// Deletes a search. Throws if nothing was deleted.
  Future<void> delete(String id);
}
