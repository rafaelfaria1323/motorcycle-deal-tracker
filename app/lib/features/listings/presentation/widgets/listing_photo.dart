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

    return Image.network(url!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => placeholder);
  }
}
