abstract interface class ColourRepository {
  /// The current user's favourite colours (`listings.colour` codes).
  Future<List<String>> getColours();

  /// Sets the current user's favourite colours; empty clears them.
  Future<void> saveColours(List<String> codes);
}
