import 'package:collector/collector.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// A photo-like picture: a diagonal gradient with a dark block, or (when
/// [flipped]) the same mirrored.
img.Image _picture({bool flipped = false}) {
  final image = img.Image(width: 320, height: 240);
  for (var y = 0; y < 240; y++) {
    for (var x = 0; x < 320; x++) {
      final xx = flipped ? 319 - x : x;
      final dark = xx > 60 && xx < 140 && y > 80 && y < 200;
      final v = dark ? 30 : (xx * 255 ~/ 320 + y * 255 ~/ 480) % 256;
      image.setPixelRgb(x, y, v, (v + 40) % 256, 255 - v);
    }
  }
  return image;
}

void main() {
  test('the same photo resized and recompressed keeps its hash', () {
    final original = photoHash(img.encodeJpg(_picture(), quality: 90))!;
    final smaller = photoHash(
      img.encodeJpg(img.copyResize(_picture(), width: 160), quality: 60),
    )!;
    final png = photoHash(img.encodePng(_picture()))!;

    expect(hashDistance(original, smaller), lessThanOrEqualTo(5));
    expect(hashDistance(original, png), lessThanOrEqualTo(5));
  });

  test('another photo is far away', () {
    final a = photoHash(img.encodeJpg(_picture()))!;
    final b = photoHash(img.encodeJpg(_picture(flipped: true)))!;

    expect(hashDistance(a, b), greaterThan(10));
  });

  test('what is not an image, or too small, has no hash', () {
    expect(photoHash([1, 2, 3]), isNull);
    expect(photoHash(const []), isNull);
    expect(photoHash(img.encodePng(img.Image(width: 4, height: 4))), isNull);
  });

  test('hashDistance counts the differing bits, sign bit too', () {
    expect(hashDistance(0, 0), 0);
    expect(hashDistance(0, 7), 3);
    expect(hashDistance(0, -1), 64);
    expect(hashDistance(-1 >>> 1, -1), 1);
  });
}
