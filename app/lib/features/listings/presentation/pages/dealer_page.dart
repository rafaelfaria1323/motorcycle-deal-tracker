import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/dealer_reliability.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../dealer_text.dart';
import '../widgets/dealer_card.dart';
import '../widgets/deals_list_item.dart';

/// A dealer's page (N.72, `/dealer?name=…`, pushed from the ad's "O
/// stand"): its figures, then every ad of it we have seen on both sites,
/// those for sale first, then the ones gone. A tap opens the ad.
class const DealerPage({required final String name, super.key})
    extends StatefulWidget {
  @override
  State<DealerPage> createState() => _DealerPageState();
}

typedef _DealerData = ({DealerReliability? figures, List<Listing> ads});

class _DealerPageState extends State<DealerPage> {
  late Future<_DealerData> _future = _load();

  Future<_DealerData> _load() async {
    final repository = getIt<DealerRepository>();
    final name = widget.name.trim();
    if (name.isEmpty) return (figures: null, ads: const <Listing>[]);
    final (figures, ads) = await (
      repository.getByName(name),
      repository.getListings(name),
    ).wait;
    return (figures: figures, ads: ads);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim();
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(name.isEmpty ? context.strings.theDealer : name),
      ),
      body: FutureBuilder<_DealerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: context.strings.couldNotLoadDealer,
              message: context.strings.checkYourConnectionAndTryAgain,
              actionLabel: context.strings.retry,
              onAction: () => setState(() => _future = _load()),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data.ads.isEmpty) {
            return StateMessage(
              icon: Icons.storefront_outlined,
              title: context.strings.noAdsOfThisDealer,
            );
          }
          return _DealerAds(figures: data.figures, ads: data.ads);
        },
      ),
    );
  }
}

class const _DealerAds({
  required final DealerReliability? figures,
  required final List<Listing> ads,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:live, :gone) = dealerAdsByStatus(ads);
    final figures = this.figures;
    return BlocBuilder<
      ListingCardPreferencesCubit,
      ListingCardPreferencesState
    >(
      bloc: getIt<ListingCardPreferencesCubit>(),
      builder: (context, cards) {
        Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleMedium),
          ),
        );
        Widget item(Listing ad) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DealsListItem(listing: ad, preferences: cards.preferences),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (figures != null)
                  SectionCard(
                    title: context.strings.theDealer,
                    footnote:
                        context.strings.fromThisDealerSListingsThatWeTrack,
                    children: [DealerFigures(dealer: figures)],
                  ),
                if (live.isNotEmpty) ...[
                  heading(context.strings.dealerLiveAds(count: live.length)),
                  for (final ad in live) item(ad),
                ],
                if (gone.isNotEmpty) ...[
                  heading(context.strings.dealerGoneAds(count: gone.length)),
                  for (final ad in gone) item(ad),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
