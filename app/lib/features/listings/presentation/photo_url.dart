/// The longest side, in pixels, that the gallery and the comparison ask
/// the photo CDN for: about 420 px of photo at 3x. The full-screen viewer
/// keeps the original size, for zoom; the cards ask for [cardPhotoBox].
const photoBox = 1280;

/// The sizes a card's photo is asked for, so the same photo comes from
/// the browser's cache whatever the screen.
const cardPhotoSteps = [480, 720, 960, photoBox];

/// The cards' side margins together (Ofertas' padding).
const cardPhotoMargin = 40;

/// The widest a card's photo is counted: wider cards (one column on a
/// tablet) show it a little softer rather than load a bigger one.
const cardPhotoMaxWidth = 600;

/// The longest side a card's photo is asked for on a screen [screenWidth]
/// logical pixels wide at [pixelRatio]: the card's width in real pixels,
/// up to the next of [cardPhotoSteps]. Worked out from the screen, not the
/// card, so `web/index.html` asks for the same address for its early
/// photos (`cardPhotoBox` there, test/photo_url_test.dart). A phone at
/// 412 px and 1.75x asks for 720 px (about a quarter of 1280's bytes).
int cardPhotoBox(double screenWidth, double pixelRatio) {
  final width = (screenWidth - cardPhotoMargin).clamp(0, cardPhotoMaxWidth);
  final needed = width * pixelRatio;
  return cardPhotoSteps.firstWhere(
    (step) => step >= needed,
    orElse: () => photoBox,
  );
}

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
