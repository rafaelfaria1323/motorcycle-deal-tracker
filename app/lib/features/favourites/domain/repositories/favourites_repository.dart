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

  /// Saves the target price of a favourite (null clears it). Throws if the
  /// listing is not a favourite.
  Future<void> saveTargetPrice(String listingId, double? targetPrice);

  /// Saves when the visit to the bike is (null: none planned). Throws if
  /// the listing is not a favourite.
  Future<void> saveVisit(String listingId, DateTime? visitAt);

  /// Records that the user opened the listing now (N.97): the database
  /// keeps the ad as it is, to tell what changes after. Throws if the
  /// listing is not a favourite.
  Future<void> markSeen(String listingId);

  /// Saves the viewing checklist of a favourite (all of it). Throws if the
  /// listing is not a favourite.
  Future<void> saveChecklist(
    String listingId,
    Map<String, ChecklistEntry> checklist,
  );

  /// The list last read on this device for the signed-in account (N.66),
  /// for when there is no connection; null when there is none.
  Future<List<Favourite>?> lastCopy();

  /// Checklists changed on this device that the database has not taken
  /// yet (no connection at the viewing), by listing.
  Future<Map<String, Map<String, ChecklistEntry>>> unsentChecklists();

  /// Keeps a checklist the database has not taken yet, or forgets it
  /// (null). Throws if this device cannot keep it.
  Future<void> keepUnsentChecklist(
    String listingId,
    Map<String, ChecklistEntry>? checklist,
  );
}
