import '../entities/listing_card_preferences.dart';

abstract interface class ListingCardPreferencesRepository {
  Future<ListingCardPreferences> get(String userId);
  Future<void> save(String userId, ListingCardPreferences preferences);
}
