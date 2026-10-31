/// Asking for every photo of a listing to be examined (P.4): the next
/// collection's photo step shows them all to the image model.
abstract interface class PhotoExamsRepository {
  /// Asks for [listingId]'s photos; returns when it was asked (the first
  /// request, also someone else's), or null when every photo already was
  /// examined. Throws [PhotoExamLimit] past the day's requests.
  Future<DateTime?> request(String listingId);
}

/// At most 5 new photo examinations per account a day.
class const PhotoExamLimit() implements Exception;
