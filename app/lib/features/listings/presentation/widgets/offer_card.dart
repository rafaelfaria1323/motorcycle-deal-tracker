import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../offer_text.dart';

/// "Quanto oferecer": where to start and the most to pay, with the reasons.
/// Hidden when the listing has no estimated value.
class OfferCard extends StatefulWidget {
  const OfferCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late final Future<MarketBehaviour?> _market = _load();

  Future<MarketBehaviour?> _load() async {
    final id = widget.listing.motorcycleId;
    if (id == null) return null;
    try {
      return await getIt<MarketBehaviourRepository>().getForModel(id);
    } catch (_) {
      // The suggestion still works without the model's figures.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    // Nothing to load for a listing that gets no suggestion anyway.
    if (suggestOffer(listing) == null) return const SizedBox.shrink();

    return FutureBuilder<MarketBehaviour?>(
      future: _market,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final offer = suggestOffer(
          listing,
          market: snapshot.data,
          daysListed: daysOnSale(listing),
        );
        if (offer == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quanto oferecer', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  offer.headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final reason in offer.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(reason)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Estimativa a partir dos preços pedidos, não de vendas. '
                  'Veja a mota antes de fazer uma proposta.',
                  style: muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
