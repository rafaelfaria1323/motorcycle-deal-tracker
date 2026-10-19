import 'package:flutter/material.dart';

class ListingPhoto extends StatelessWidget {
  const ListingPhoto({this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.two_wheeler, size: 48)),
    );

    if (url == null) return placeholder;

    return Image.network(
      url!,
      fit: BoxFit.cover,
      // The photo sites send no CORS headers, so Flutter can't download the
      // photo itself; a plain <img> element shows it. Going straight to it
      // saves a refused request per photo.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
