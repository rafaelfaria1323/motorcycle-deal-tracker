import '../domain/entities/listing.dart';

/// How many of a listing's first photos the image model sees, and so how
/// many an admin can mark for it to learn from (the collector's
/// `photosPerListing`; `photo_marks` allows photos 0-2).
const markablePhotos = 3;

/// Where a listing's examination of every photo (P.4) stands.
enum PhotoExam {
  /// Nothing to ask: no photos past the first ones, not a live listing of
  /// a collected model.
  none,

  /// A signed-in account can ask for it.
  available,

  /// Asked for: the photo step started by the request does it.
  requested,

  /// Every photo was examined.
  done,
}

/// Where [listing]'s examination of every photo stands.
PhotoExam photoExamOf(Listing listing) {
  if (listing.photosExaminedAllAt != null) return PhotoExam.done;
  if (!listing.isLive ||
      listing.motorcycleId == null ||
      listing.images.length <= markablePhotos) {
    return PhotoExam.none;
  }
  if (listing.photoExamRequestedAt != null) {
    return PhotoExam.requested;
  }
  return PhotoExam.available;
}
