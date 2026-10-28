import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/photo_hint.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/photo_hints_text.dart';

Listing listing(List<PhotoHint> hints, {int photos = 3}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: [for (var i = 0; i < photos; i++) 'https://img/$i'],
  photoHints: hints,
);

void main() {
  test('every code the image model gives has words in both languages', () {
    for (final code in [
      'crashed',
      'fallen',
      'scratches',
      'broken_parts',
      'missing_parts',
      'rust',
    ]) {
      for (final language in AppLanguage.values) {
        expect(photoHintLabel(code, language: language), isNotEmpty);
      }
    }
    expect(photoHintLabel('ok'), isNull);
    expect(photoHintLabel('something_new'), isNull);
  });

  test('a line per known hint, with its photo counted from 1', () {
    final lines = photoHintLines(
      listing(const [
        PhotoHint(code: 'fallen', photo: 2, share: 0.8),
        PhotoHint(code: 'something_new', photo: 0, share: 0.7),
        PhotoHint(code: 'scratches', photo: 0, share: 0.6),
      ]),
    );
    expect(lines, [
      (label: 'Possível queda: a mota no chão', photoLabel: 'Foto 3', photo: 2),
      (label: 'Possíveis riscos ou raspões', photoLabel: 'Foto 1', photo: 0),
    ]);
    expect(
      photoHintLines(
        listing(const [PhotoHint(code: 'rust', photo: 1, share: 0.9)]),
        language: AppLanguage.english,
      ),
      [(label: 'Possible rust', photoLabel: 'Photo 2', photo: 1)],
    );
  });

  test('a hint on a photo the listing no longer has is left out', () {
    expect(
      photoHintLines(
        listing(const [
          PhotoHint(code: 'rust', photo: 3, share: 0.9),
          PhotoHint(code: 'rust', photo: -1, share: 0.9),
        ]),
      ),
      isEmpty,
    );
    expect(photoHintLines(listing(const [])), isEmpty);
  });
}
