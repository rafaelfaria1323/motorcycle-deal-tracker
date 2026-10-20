import 'place.dart';

abstract interface class HomeRepository {
  /// The current user's home place; null when none is set.
  Future<Place?> getHome();

  /// Places whose name starts with [text] (accents and case ignored).
  Future<List<Place>> search(String text);

  /// Sets the current user's home.
  Future<void> saveHome(Place place);
}
