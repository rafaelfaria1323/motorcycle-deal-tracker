import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../market_behaviour_text.dart';

class MarketBehaviourSection extends StatefulWidget {
  const MarketBehaviourSection({required this.listing, super.key});

  final Listing listing;

  @override
  State<MarketBehaviourSection> createState() => _MarketBehaviourSectionState();
}

class _MarketBehaviourSectionState extends State<MarketBehaviourSection> {
  Future<MarketBehaviour?>? _future;

  @override
  void initState() {
    super.initState();
    final id = widget.listing.motorcycleId;
    if (id != null) {
      _future = getIt<MarketBehaviourRepository>().getForModel(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<MarketBehaviour?>(
      future: future,
      builder: (context, snapshot) {
        final market = snapshot.data;
        // Secondary information: hide it while loading or on any error.
        if (market == null) return const SizedBox.shrink();

        final since = widget.listing.publishedAt ?? widget.listing.firstSeenAt;
        final days = since == null
            ? null
            : DateTime.now().difference(since).inDays;
        final theme = Theme.of(context);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mercado deste modelo',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final line in marketLines(
                  market,
                  daysListed: days,
                  firstSeenOnly: widget.listing.publishedAt == null,
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.insights_outlined,
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
      },
    );
  }
}
