import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The photo's difference hash (dHash): grey, shrunk to 9x8, one bit per
/// pair of neighbours in a row (left brighter than right). The same photo
/// resized, recompressed or lightly cropped keeps nearly every bit, so two
/// photos are the same when their hashes differ in a few bits
/// ([hashDistance]). Null when [bytes] are not an image we can read.
int? photoHash(List<int> bytes) {
  final img.Image? image;
  try {
    image = img.decodeImage(Uint8List.fromList(bytes));
  } on Object {
    return null;
  }
  if (image == null || image.width < 9 || image.height < 8) return null;
  final small = img.copyResize(
    img.grayscale(image),
    width: 9,
    height: 8,
    interpolation: img.Interpolation.average,
  );
  var hash = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).luminance;
      final right = small.getPixel(x + 1, y).luminance;
      hash = (hash << 1) | (left > right ? 1 : 0);
    }
  }
  return hash;
}

/// How many bits two hashes differ in (0-64).
int hashDistance(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    x &= x - 1;
    count++;
  }
  return count;
}
