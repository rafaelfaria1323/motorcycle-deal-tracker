import '../entities/shared_listing_draft.dart';

abstract interface class SharedListingsRepository {
  /// Saves the ad (or updates it if it was saved before) and returns the
  /// listing's id. Needs a signed-in account.
  Future<String> save(SharedListingDraft draft);
}
