import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/listing.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../negotiation_text.dart';
import 'deals_list_item.dart';

/// The two actions under Negociar's cheaper-similar argument (N.94): every
/// one of those ads in a sheet, and the comparison of this ad with the
/// cheapest of them.
class const CheaperSimilarActions({
  required final Listing listing,
  required final List<Listing> cheaper,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => showCheaperSimilar(context, listing, cheaper),
            icon: const Icon(Icons.list_alt, size: 18),
            label: Text(
              context.strings.seeCheaperSimilar(count: cheaper.length),
            ),
          ),
          _CompareButton(listing: listing, cheaper: cheaper),
        ],
      ),
    );
  }
}

/// This ad beside the cheapest of [cheaper] in the comparison.
class const _CompareButton({
  required final Listing listing,
  required final List<Listing> cheaper,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () =>
        context.push(AppRoutes.compare(compareWithCheaper(listing, cheaper))),
    icon: const Icon(Icons.compare_arrows, size: 18),
    label: Text(context.strings.compareWithCheaper(count: cheaper.length)),
  );
}

/// The cheaper ads of [listing]'s model, cheapest first, as Ofertas'
/// cards, each under how it compares with [listing] (N.96: the price gap,
/// Deal Score, risk and distance): a tap opens one, its "Comparar" adds
/// it to the comparison.
Future<void> showCheaperSimilar(
  BuildContext context,
  Listing listing,
  List<Listing> cheaper,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _CheaperSimilarSheet(listing: listing, cheaper: cheaper),
);

class const _CheaperSimilarSheet({
  required final Listing listing,
  required final List<Listing> cheaper,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) =>
          BlocBuilder<ListingCardPreferencesCubit, ListingCardPreferencesState>(
            bloc: getIt<ListingCardPreferencesCubit>(),
            builder: (context, cards) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.strings.cheaperSimilarTitle(model: listing.model),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.strings.cheaperSimilarIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CompareButton(listing: listing, cheaper: cheaper),
                ),
                const SizedBox(height: 8),
                for (final ad in cheaper)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (cheaperVersusText(
                              listing,
                              ad,
                              language: context.language,
                            )
                            case final versus?)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              versus,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        DealsListItem(
                          listing: ad,
                          preferences: cards.preferences,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
