import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../new_price_text.dart';

class NewPriceCard extends StatelessWidget {
  const NewPriceCard({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final lines = newPriceLines(listing);
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comparação com uma nova', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
