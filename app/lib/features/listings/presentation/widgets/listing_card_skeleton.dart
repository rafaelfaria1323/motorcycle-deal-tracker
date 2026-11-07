import 'package:flutter/material.dart';

import 'listing_card.dart';

/// The shape of a [ListingCard] while the offers load, so the page doesn't
/// jump from a spinner to a grid.
class const ListingCardSkeleton({super.key}) extends StatelessWidget {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.7,
                            child: bar(double.infinity, 20),
                          ),
                          bar(110, 14),
                        ],
                      ),
                    ),
                    bar(56, 48),
                  ],
                ),
                const SizedBox(height: 10),
                bar(double.infinity, 66),
                const SizedBox(height: 10),
                Row(spacing: 6, children: [bar(90, 22), bar(70, 22)]),
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
