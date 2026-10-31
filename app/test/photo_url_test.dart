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

  test("index.html's early photos ask for the same box", () {
    final html = File('web/index.html').readAsStringSync();
    final box = RegExp(r'var PHOTO_BOX = (\d+);').firstMatch(html);
    expect(box, isNotNull, reason: 'no PHOTO_BOX in index.html');
    expect(int.parse(box![1]!), photoBox);
  });
}
