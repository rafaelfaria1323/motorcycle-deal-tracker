import 'package:flutter/material.dart';

import 'listing_card.dart';

/// The shape of a [ListingCard] while the offers load, so the page doesn't
/// jump from a spinner to a grid.
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: ListingCard.photoHeight, color: fill),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: bar(double.infinity, 20),
                ),
                const SizedBox(height: 12),
                bar(100, 30),
                const SizedBox(height: 12),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: bar(double.infinity, 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: bar(120, 12)),
        ],
      ),
    );
  }
}
