import 'package:flutter/material.dart';

import '../photo_url.dart';

class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    this.url,
    this.fit = BoxFit.cover,
    this.fullSize = false,
    super.key,
  });

  final String? url;
  final BoxFit fit;

  /// The photo as the site has it, for zoom; otherwise at most [photoBox]
  /// pixels on its longest side.
  final bool fullSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.two_wheeler, size: 48)),
    );

    if (url == null) return placeholder;

    return Image.network(
      fullSize ? url! : photoAtSize(url!),
      fit: fit,
      // The photo sites send no CORS headers, so Flutter can't download the
      // photo itself; a plain <img> element shows it. Going straight to it
      // saves a refused request per photo.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
