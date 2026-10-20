import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../offer_text.dart';

/// "Quanto oferecer": where to start and the most to pay, the offers to
/// make in turn, the reasons, and what to answer to the seller's
/// counter-offer. Hidden when the listing has no estimated value.
class OfferCard extends StatefulWidget {
  const OfferCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late final Future<MarketBehaviour?> _market = _load();
  final _counter = TextEditingController();

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

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
                for (final (i, step) in offer.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${i + 1}. ${step.label}')),
                        Text(
                          Formatters.price(step.price),
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
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
                const SizedBox(height: 12),
                TextField(
                  controller: _counter,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'O vendedor pediu',
                    suffixText: '€',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (parseCounterOffer(_counter.text) case final counter?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      offer.replyTo(counter),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
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
