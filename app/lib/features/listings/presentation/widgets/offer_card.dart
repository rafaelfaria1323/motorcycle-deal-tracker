import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../favourites/domain/entities/favourite.dart';
import '../../domain/entities/listing.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../../market/domain/repositories/market_behaviour_repository.dart';
import '../../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../../favourites/presentation/cubit/favourites_state.dart';
import '../../../favourites/presentation/widgets/target_price_tile.dart';
import '../negotiation_text.dart';
import '../offer_text.dart';
import 'counter_offer_reply.dart';
import '../../../../core/localization/localizations.dart';

/// "Quanto oferecer": the offers to make in turn (each with its message),
/// what to say to justify them, what to answer to the seller's
/// counter-offer, and, for a favourite, the price to be alerted at. After
/// the visit, the problems marked in the checklist come off the offer.
/// Hidden when the listing has no estimated value.
class const OfferCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late final Future<(MarketBehaviour?, List<Listing>)> _data = _load();
  final _counter = TextEditingController();
  var _showReasons = false;

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  Future<(MarketBehaviour?, List<Listing>)> _load() async {
    final listing = widget.listing;
    final id = listing.motorcycleId;
    // The suggestion and the arguments still work without either.
    final market = id == null
        ? Future<MarketBehaviour?>.value()
        : getIt<MarketBehaviourRepository>()
              .getForModel(id)
              .then<MarketBehaviour?>((m) => m, onError: (Object _) => null);
    final cheaper = getIt<ListingsRepository>()
        .getCheaperSimilar(listing)
        .then((l) => l, onError: (Object _) => const <Listing>[]);
    return (await market, await cheaper);
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    // Nothing to load for a listing that gets no suggestion anyway.
    if (suggestOffer(listing, language: context.language) == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<(MarketBehaviour?, List<Listing>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return const SizedBox.shrink();
        }
        final (market, cheaper) = snapshot.data ?? (null, const <Listing>[]);
        return BlocBuilder<FavouritesCubit, FavouritesState>(
          bloc: getIt<FavouritesCubit>(),
          builder: (context, favourites) {
            final favourite = favourites.favouriteOf(listing.id);
            final days = daysOnSale(listing);
            final planned = suggestOffer(
              listing,
              market: market,
              daysListed: days,
              language: context.language,
            );
            if (planned == null) return const SizedBox.shrink();
            final visit = visitFindings(
              favourite?.checklist ?? const {},
              engineCc: listing.engineCc,
              language: context.language,
            );
            final arguments = negotiationArguments(
              listing,
              market: market,
              daysListed: days,
              cheaper: cheaper,
              visit: visit,
              language: context.language,
            );
            return _content(
              context,
              afterVisit(planned, visit, language: context.language),
              visit,
              arguments,
              favourite,
              sellerUrgency(
                listing,
                market: market,
                daysListed: days,
                language: context.language,
              ),
            );
          },
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    OfferSuggestion offer,
    VisitFindings visit,
    List<String> arguments,
    Favourite? favourite,
    SellerUrgency urgency,
  ) {
    final listing = widget.listing;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SectionCard(
      title: context.strings.howMuchToOffer,
      footnote: context.strings.estimateBasedOnAskingPricesNotSalesSee,
      children: [
        Text(
          offer.headline(language: context.language),
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 4),
        BulletLine(urgency.text(language: context.language), icon: Icons.speed),
        if (visit.blockers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.strings.visitBlockers(blockers: visit.blockers.join(', ')),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        for (final (i, step) in offer.steps(language: context.language).indexed)
          _StepRow(
            number: i + 1,
            step: step,
            onCopy: () => copyMessage(context, step.message),
          ),
        if (arguments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.strings.arguments, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final argument in arguments)
            BulletLine(argument, icon: Icons.chat_bubble_outline),
        ],
        if (listing.sellerType == .dealer) ...[
          const SizedBox(height: 16),
          Text(
            context.strings.atDealerAlsoAskFor,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final ask in dealerAsks(listing, language: context.language))
            BulletLine(ask, icon: Icons.add_task),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => copyMessage(
                context,
                dealerMessage(
                  listing,
                  offer.opening,
                  language: context.language,
                ),
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(context.strings.copyMessageForDealer),
            ),
          ),
        ],
        const SizedBox(height: 16),
        CounterOfferReply(offer: offer, controller: _counter),
        const SizedBox(height: 8),
        if (favourite == null)
          Text(context.strings.addItToFavouritesStarToSetYour, style: muted)
        else
          TargetPriceTile(favourite: favourite, suggested: offer.opening),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showReasons = !_showReasons),
            child: Text(
              _showReasons
                  ? context.strings.hideCalculation
                  : context.strings.howItWasCalculated,
            ),
          ),
        ),
        if (_showReasons)
          for (final reason in offer.reasons) BulletLine(reason),
      ],
    );
  }
}

/// "1  Primeira proposta ........ 7 950 €  [copiar]": one offer of the plan.
class const _StepRow({
  required final int number,
  required final OfferStep step,
  required final VoidCallback onCopy,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Text('$number', style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(step.label)),
        Text(
          Formatters.price(step.price, language: context.language),
          style: theme.textTheme.titleSmall,
        ),
        IconButton(
          tooltip: context.strings.copyMessage,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: onCopy,
        ),
      ],
    );
  }
}
