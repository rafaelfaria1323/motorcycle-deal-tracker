/// The longest side, in pixels, that the cards, the gallery and the
/// comparison ask the photo CDN for: about 420 px of card at 3x. The
/// full-screen viewer keeps the original size, for zoom.
/// `web/index.html` asks for the same (`PHOTO_BOX`, test/photo_url_test.dart),
/// so its early photos come from the browser's cache.
const photoBox = 1280;

final _cdnImage = RegExp(
  r'^(https://ireland\.apollo\.olxcdn\.com(?::443)?/v1/files/[^/?#;]+/image)'
  r'((?:;[^/?#]*)?)$',
);
final _size = RegExp(r'^s=(\d+)x(\d+)$');

/// [url] at most [box] pixels on its longest side, when it is the photo
/// CDN's (both sites serve photos from it, `;s=<width>x<height>` sizing
/// the image); any other address, or a photo already that small, stays
/// as it is. The original's proportions are kept; an unknown size asks
/// for 4:3, the sites' usual shape.
String photoAtSize(String url, [int box = photoBox]) {
  final match = _cdnImage.firstMatch(url);
  if (match == null) return url;
  var width = box;
  var height = box * 3 ~/ 4;
  final kept = <String>[match[1]!];
  for (final param in match[2]!.split(';')) {
    final size = _size.firstMatch(param);
    if (size != null) {
      final w = int.parse(size[1]!);
      final h = int.parse(size[2]!);
      if (w <= box && h <= box) return url;
      final longest = w > h ? w : h;
      width = (w * box / longest).round();
      height = (h * box / longest).round();
    } else if (param.isNotEmpty && !param.startsWith('s=')) {
      kept.add(param);
    }
  }
  return [...kept, 's=${width}x$height'].join(';');
}
