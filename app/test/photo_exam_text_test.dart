import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/photo_exam_text.dart';

Listing listing({
  int photos = 8,
  ListingStatus status = ListingStatus.active,
  String? motorcycleId = 'm1',
  DateTime? requestedAt,
  DateTime? doneAt,
}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  motorcycleId: motorcycleId,
  status: status,
  sellerType: SellerType.private,
  images: [for (var i = 0; i < photos; i++) 'https://img/$i'],
  photoExamRequestedAt: requestedAt,
  photosExaminedAllAt: doneAt,
);

void main() {
  final at = DateTime.utc(2026, 10, 28);

  test('a live ad of a collected model with photos past the first ones '
      'can be examined in full', () {
    expect(photoExamOf(listing()), PhotoExam.available);
    expect(
      photoExamOf(listing(status: ListingStatus.priceChanged)),
      PhotoExam.available,
    );
    expect(
      photoExamOf(listing(photos: markablePhotos + 1)),
      PhotoExam.available,
    );
  });

  test('nothing to ask without more photos, gone or not collected', () {
    expect(photoExamOf(listing(photos: markablePhotos)), PhotoExam.none);
    expect(photoExamOf(listing(status: ListingStatus.removed)), PhotoExam.none);
    expect(photoExamOf(listing(status: ListingStatus.sold)), PhotoExam.none);
    expect(photoExamOf(listing(motorcycleId: null)), PhotoExam.none);
  });

  test('asked for', () {
    expect(photoExamOf(listing(requestedAt: at)), PhotoExam.requested);
    // A request for an ad that has since gone stays unshown.
    expect(
      photoExamOf(listing(requestedAt: at, status: ListingStatus.removed)),
      PhotoExam.none,
    );
  });

  test('done stays done, also once the ad is gone', () {
    expect(photoExamOf(listing(doneAt: at)), PhotoExam.done);
    expect(
      photoExamOf(listing(doneAt: at, status: ListingStatus.removed)),
      PhotoExam.done,
    );
  });
}
