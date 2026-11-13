import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/photo_url.dart';

const _cdn = 'https://ireland.apollo.olxcdn.com/v1/files/abc123-PT/image';

void main() {
  test('a large CDN photo is asked for at the box, proportions kept', () {
    expect(photoAtSize('$_cdn;s=4000x3000'), '$_cdn;s=1280x960');
    expect(photoAtSize('$_cdn;s=3000x4000'), '$_cdn;s=960x1280');
    expect(photoAtSize('$_cdn;s=1920x1080', 640), '$_cdn;s=640x360');
  });

  test('other parameters stay, an unusable size is replaced', () {
    expect(photoAtSize('$_cdn;q=80;s=4000x3000'), '$_cdn;q=80;s=1280x960');
    expect(photoAtSize('$_cdn;s={width}x{height}'), '$_cdn;s=1280x960');
    expect(photoAtSize(_cdn), '$_cdn;s=1280x960');
    expect(
      photoAtSize(
        'https://ireland.apollo.olxcdn.com:443/v1/files/x/image;s=2000x2000',
      ),
      'https://ireland.apollo.olxcdn.com:443/v1/files/x/image;s=1280x1280',
    );
  });

  test('small photos and other addresses are left alone', () {
    expect(photoAtSize('$_cdn;s=640x480'), '$_cdn;s=640x480');
    expect(photoAtSize('$_cdn;s=1280x960'), '$_cdn;s=1280x960');
    for (final url in [
      'https://example.com/v1/files/abc/image;s=4000x3000',
      'https://ireland.apollo.olxcdn.com/v1/files/abc/image;s=4000x3000?x=1',
      'http://ireland.apollo.olxcdn.com/v1/files/abc/image;s=4000x3000',
      'https://ireland.apollo.olxcdn.com/v1/files/abc/other;s=4000x3000',
    ]) {
      expect(photoAtSize(url), url);
    }
  });

  test('a card asks for its width in real pixels, up to the next step', () {
    // Lighthouse's phone: 412 px at 1.75x -> 372 x 1.75 = 651.
    expect(cardPhotoBox(412, 1.75), 720);
    // An iPhone at 3x: 350 x 3 = 1050.
    expect(cardPhotoBox(390, 3), 1280);
    expect(cardPhotoBox(360, 1), 480);
    expect(cardPhotoBox(520, 1), 480, reason: 'exactly a step');
    // Wide screens count at most 600 px of card.
    expect(cardPhotoBox(1440, 1), 720);
    expect(cardPhotoBox(1440, 2), 1280);
    expect(cardPhotoBox(1440, 4), photoBox, reason: 'never above the box');
    expect(cardPhotoBox(20, 2), 480, reason: 'a tiny window');
    expect(
      photoAtSize('$_cdn;s=4000x3000', cardPhotoBox(412, 1.75)),
      '$_cdn;s=720x540',
    );
  });

  test("index.html's early photos ask for the cards' size", () {
    final html = File('web/index.html').readAsStringSync();
    int constant(String name) {
      final match = RegExp('var $name = (\\d+);').firstMatch(html);
      expect(match, isNotNull, reason: 'no $name in index.html');
      return int.parse(match![1]!);
    }

    final steps = RegExp(r'var PHOTO_STEPS = \[([\d, ]+)\];').firstMatch(html);
    expect(steps, isNotNull, reason: 'no PHOTO_STEPS in index.html');
    expect(
      steps![1]!.split(',').map((step) => int.parse(step.trim())),
      cardPhotoSteps,
    );
    expect(constant('CARD_MARGIN'), cardPhotoMargin);
    expect(constant('CARD_MAX_WIDTH'), cardPhotoMaxWidth);
    expect(
      html,
      contains(
        'var PHOTO_BOX = cardPhotoBox(\n'
        '      Math.min(window.innerWidth, window.screen.width || window.innerWidth),\n'
        '      window.devicePixelRatio || 1);',
      ),
    );
  });
}
