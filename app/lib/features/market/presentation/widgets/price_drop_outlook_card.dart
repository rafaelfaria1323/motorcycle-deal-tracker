import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../domain/entities/price_drop_outlook.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../price_drop_outlook_text.dart';

/// "Esperar ou comprar já?" (N.83): what the model's other ads did in the
/// 30 days after they were as old as this one. Only for a live listing
/// with a model and a real price; hidden while loading, on an error and
/// below 5 ads followed (`minMarketData`).
class const PriceDropOutlookCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<PriceDropOutlookCard> createState() => _PriceDropOutlookCardState();
}

class _PriceDropOutlookCardState extends State<PriceDropOutlookCard> {
  Future<PriceDropOutlook?>? _future;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    if (listing.isLive &&
        listing.motorcycleId != null &&
        listing.askingPrice != null) {
      _future = _load();
    }
  }

  // An error leaves the snapshot without data: the card stays hidden.
  Future<PriceDropOutlook?> _load() async =>
      getIt<MarketBehaviourRepository>().getPriceDropOutlook(widget.listing.id);

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<PriceDropOutlook?>(
      future: future,
      builder: (context, snapshot) {
        final outlook = snapshot.data;
        final text = outlook == null
            ? null
            : priceDropOutlookText(outlook, language: context.language);
        if (text == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return SectionCard(
          title: context.strings.waitOrBuyNow,
          footnote: context.strings.priceDropOutlookFootnote,
          children: [
            Text(text.intro),
            const SizedBox(height: 4),
            for (final line in text.lines) BulletLine(line),
            const SizedBox(height: 8),
            Text(
              text.advice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}
