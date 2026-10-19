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
      // On the web the app first downloads the photo itself, which the photo
      // site's CORS rules can refuse; a plain <img> element still shows it.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
