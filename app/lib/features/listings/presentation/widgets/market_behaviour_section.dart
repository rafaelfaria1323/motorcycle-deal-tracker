import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../market_behaviour_text.dart';
import '../price_position_text.dart';
import 'price_position_strip.dart';

class MarketBehaviourSection extends StatefulWidget {
  const MarketBehaviourSection({required this.listing, super.key});

  final Listing listing;

  @override
  State<MarketBehaviourSection> createState() => _MarketBehaviourSectionState();
}

class _MarketBehaviourSectionState extends State<MarketBehaviourSection> {
  Future<(MarketBehaviour?, List<double>)>? _future;

  @override
  void initState() {
    super.initState();
    final id = widget.listing.motorcycleId;
    if (id != null) _future = _load(id);
  }

  Future<(MarketBehaviour?, List<double>)> _load(String motorcycleId) async {
    final repository = getIt<MarketBehaviourRepository>();
    final (market, prices) = await (
      repository.getForModel(motorcycleId),
      // The comparison is extra: without it the rest still shows.
      repository
          .getLivePrices(motorcycleId)
          .catchError((Object _) => <String, double>{}),
    ).wait;
    final listing = widget.listing;
    final others = [
      for (final MapEntry(:key, :value) in prices.entries)
        // Neither this listing nor the one it repeats.
        if (key != listing.id && key != listing.duplicateOf) value,
    ];
    return (market, others);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<(MarketBehaviour?, List<double>)>(
      future: future,
      builder: (context, snapshot) {
        final (market, others) = snapshot.data ?? (null, const <double>[]);
        // Secondary information: hide it while loading or on any error.
        if (market == null) return const SizedBox.shrink();

        final price = widget.listing.price;
        final position = pricePosition(price, others);
        final priceLine = pricePositionLine(price, others);

        final since = widget.listing.publishedAt ?? widget.listing.firstSeenAt;
        final days = since == null
            ? null
            : DateTime.now().difference(since).inDays;

        return SectionCard(
          title: 'Mercado deste modelo',
          children: [
            if (priceLine != null) _Line(priceLine),
            if (position != null) ...[
              const SizedBox(height: 4),
              PricePositionStrip(position: position),
              const SizedBox(height: 8),
            ],
            for (final line in marketLines(
              market,
              daysListed: days,
              firstSeenOnly: widget.listing.publishedAt == null,
            ))
              _Line(line),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      BulletLine(text, icon: Icons.insights_outlined);
}
