import '../entities/favourite.dart';

abstract interface class FavouritesRepository {
  /// The current user's favourites with their listings, newest first.
  Future<List<Favourite>> getAll();

  /// Adds a listing to the current user's favourites.
  Future<void> add(String listingId);

  /// Takes a listing out of the favourites. Throws if nothing was removed.
  Future<void> remove(String listingId);

  /// Saves the note of a favourite (null clears it). Throws if the listing
  /// is not a favourite.
  Future<void> saveNote(String listingId, String? note);
}
