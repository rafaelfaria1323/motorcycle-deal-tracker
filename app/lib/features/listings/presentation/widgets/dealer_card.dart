import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/dealer_reliability.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../dealer_text.dart';
import '../../../../core/localization/localizations.dart';

/// "O stand": what we have seen of the dealer's ads on both sites. Only for
/// dealers (private sellers' names are never stored); hidden while loading
/// or on any error. Its button opens the dealer's page (N.72).
class const DealerCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<DealerCard> createState() => _DealerCardState();
}

class _DealerCardState extends State<DealerCard> {
  Future<DealerReliability?>? _future;

  @override
  void initState() {
    super.initState();
    if (dealerLookupName(widget.listing) case final name?) {
      _future = getIt<DealerRepository>()
          .getByName(name)
          .catchError((Object _) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    final name = dealerLookupName(widget.listing);
    if (future == null || name == null) return const SizedBox.shrink();

    return FutureBuilder<DealerReliability?>(
      future: future,
      builder: (context, snapshot) {
        final dealer = snapshot.data;
        if (dealer == null) return const SizedBox.shrink();

        return SectionCard(
          title: context.strings.theDealer,
          footnote: context.strings.fromThisDealerSListingsThatWeTrack,
          children: [
            DealerFigures(dealer: dealer),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.dealer(name)),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(context.strings.seeDealerAds(bikes: dealer.bikes)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The dealer's headline and one line per warning sign: the ad's "O stand"
/// and the top of the dealer's page.
class const DealerFigures({required final DealerReliability dealer, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dealerHeadline(dealer, language: context.language)),
        const SizedBox(height: 8),
        for (final line in dealerLines(dealer, language: context.language))
          BulletLine(line),
      ],
    );
  }
}
