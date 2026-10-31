/// What the full-screen photos route (`/deals/<id>/photos`) gets as its
/// `extra`: the photos and the one to show first. A plain map of strings
/// and an int, so the browser's history keeps it (go_router stores `extra`
/// as JSON) and back/forward open the same photo again.
class const PhotoViewerArgs({
  required final List<String> images,
  required final int index,
}) {
  Map<String, Object> toExtra() => {'images': images, 'index': index};

  /// Null when [extra] isn't one of these (a typed or reloaded address
  /// carries none): the route then shows the listing instead.
  static PhotoViewerArgs? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final images = extra['images'];
    if (images is! List || images.isEmpty) return null;
    final urls = [
      for (final image in images)
        if (image is String) image,
    ];
    if (urls.length != images.length) return null;
    final index = extra['index'];
    return PhotoViewerArgs(
      images: urls,
      index: index is int && index >= 0 && index < urls.length ? index : 0,
    );
  }
}
