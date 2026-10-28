/// An admin's marks on the first photos of a listing (P.3): the collector
/// trains the image model's `learned` hint on them.
abstract interface class PhotoMarksRepository {
  /// The caller's marks by photo index (true: a problem, false: fine);
  /// empty for anyone but an admin.
  Future<Map<int, bool>> marks(String listingId);

  /// Marks [photo] (from 0) as a problem or fine, or clears it (null).
  Future<void> setMark(String listingId, int photo, bool? problem);
}
