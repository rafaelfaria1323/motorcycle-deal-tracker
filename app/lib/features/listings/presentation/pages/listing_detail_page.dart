import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../cubit/listing_detail_cubit.dart';
import '../cubit/listing_detail_state.dart';
import '../../../valuation/presentation/import_cost_text.dart';
import '../listing_dates_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import '../score_explanation.dart';
import '../widgets/also_listed_section.dart';
import '../widgets/deal_score_badge.dart';
import '../widgets/dealer_card.dart';
import '../widgets/facts_card.dart';
import '../widgets/favourite_widgets.dart';
import '../../../valuation/presentation/widgets/import_cost_card.dart';
import '../widgets/market_behaviour_section.dart';
import '../widgets/new_price_card.dart';
import '../widgets/offer_card.dart';
import '../../../valuation/presentation/widgets/ownership_cost_card.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/photo_hints_card.dart';
import '../widgets/price_change_tag.dart';
import '../widgets/price_history_section.dart';
import '../widgets/score_explanation_card.dart';
import '../widgets/seller_message_card.dart';
import '../widgets/viewing_checklist_card.dart';
import '../../../../core/localization/localizations.dart';

class const ListingDetailPage({
  required final String listingId,

  /// Opened from a list of ads ([AppRoutes.fromList]): it starts on the
  /// part last read. Otherwise (a notification, an alert, a shared link)
  /// on Avaliação, about this bike.
  final bool keepSection = false,
  super.key,
}) extends StatefulWidget {
  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  /// Whether the bike's name has scrolled out of view: the bar then
  /// names it (F.4).
  final _nameHidden = ValueNotifier(false);

  @override
  void dispose() {
    _nameHidden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listingId;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => goBack(context, fallback: AppRoutes.deals),
        ),
        title: BlocBuilder<ListingDetailCubit, ListingDetailState>(
          builder: (context, state) => ValueListenableBuilder(
            valueListenable: _nameHidden,
            builder: (context, hidden, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: switch (state.listing) {
                final listing? when hidden => _CompactTitle(
                  key: const ValueKey('compact'),
                  listing: listing,
                ),
                _ => Text(context.strings.listingListingDetailPage),
              },
            ),
          ),
        ),
        actions: [
          // The star needs the listing (the favourites page shows it).
          BlocBuilder<ListingDetailCubit, ListingDetailState>(
            builder: (context, state) => state.listing == null
                ? const SizedBox.shrink()
                : FavouriteButton(listing: state.listing!),
          ),
          _CompareButton(listingId: listingId),
        ],
      ),
      body: BlocBuilder<ListingDetailCubit, ListingDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case .loading:
              return const Center(child: CircularProgressIndicator());
            case .notFound:
              return StateMessage(
                icon: Icons.search_off,
                title: context.strings.listingNotFound,
                message: context.strings.itMayHaveBeenRemovedOrLinkIs,
                actionLabel: context.strings.viewDeals,
                onAction: () => context.go(AppRoutes.deals),
              );
            case .failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: context.strings.couldNotLoadListing,
                message: context.strings.checkYourConnectionAndTryAgain,
                actionLabel: context.strings.retry,
                onAction: () =>
                    context.read<ListingDetailCubit>().load(listingId),
              );
            case .success:
              return _Content(
                listing: state.listing!,
                keepSection: widget.keepSection,
                nameHidden: _nameHidden,
              );
          }
        },
      ),
    );
  }
}

/// The four parts of the page, picked at the top so the page stays short:
/// the verdict, the ad's own details, the market and negotiating.
enum _Section {
  verdict,
  details,
  market,
  negotiate;

  String label({AppLanguage language = .portuguese}) => switch (this) {
    verdict => language.messages.assessment,
    details => language.messages.details,
    market => language.messages.market,
    negotiate => language.messages.negotiate,
  };
}

/// The bar's title once the page's own heading has scrolled away: the
/// bike, then its year and price (F.4).
class const _CompactTitle({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: listing.name, style: theme.textTheme.titleLarge),
          TextSpan(
            text: '\n${compactTitleLine(listing, language: context.language)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class const _Content({
  required final Listing listing,
  required final bool keepSection,
  required final ValueNotifier<bool> nameHidden,
}) extends StatefulWidget {
  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  // Kept while the app runs, so going from one listing of a list to the
  // next opens the part that was being compared.
  static var _lastSection = _Section.verdict;

  late var _section = widget.keepSection ? _lastSection : _Section.verdict;
  // Parts are built when first opened and then kept (offstage), so a
  // counter-offer being typed or a loaded chart survives switching.
  late final _opened = {_section};

  final _scroll = ScrollController();
  final _nameKey = GlobalKey();
  final _listKey = GlobalKey();

  Listing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _lastSection = _section;
    _scroll.addListener(_scheduleCheck);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  var _checkPending = false;

  /// Measured once the frame is laid out: during a scroll the positions
  /// are still the last frame's.
  void _scheduleCheck() {
    if (_checkPending) return;
    _checkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPending = false;
      if (mounted) _checkName();
    });
  }

  /// Tells the bar whether the bike's name is above the top of the list.
  void _checkName() {
    final list = _listKey.currentContext?.findRenderObject();
    if (list is! RenderBox) return;
    final name = _nameKey.currentContext?.findRenderObject();
    // The heading is in the list's first item, which the list lets go
    // once it is far above the screen (a long jump or a fast fling).
    if (name is! RenderBox) {
      widget.nameHidden.value = true;
      return;
    }
    final bottom = name.localToGlobal(
      Offset(0, name.size.height),
      ancestor: list,
    );
    widget.nameHidden.value = bottom.dy < 0;
  }

  void _select(_Section section) => setState(() {
    _section = section;
    _lastSection = section;
    _opened.add(section);
  });

  Future<void> _openOriginal(BuildContext context) async {
    final messageStrings = context.strings;

    final uri = adAddress(listing);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      showMessage(
        ScaffoldMessenger.of(context),
        messageStrings.couldNotOpenListing,
      );
    }
  }

  List<Widget> _cards(_Section section) {
    final description = listing.description;
    return switch (section) {
      _Section.verdict => [
        if (listing.dealScore == null)
          SectionCard(
            title: context.strings.whyThisScore,
            children: [Text(context.strings.thisListingDoesNotHaveScoreYet)],
          )
        else
          ScoreExplanationCard(listing: listing),
        PhotoHintsCard(listing: listing),
        AlsoListedSection(listing: listing),
        DealerCard(listing: listing),
      ],
      _Section.negotiate => [
        OfferCard(listing: listing),
        SellerMessageCard(listing: listing),
        ViewingChecklistCard(listingId: listing.id),
      ],
      _Section.market => [
        MarketBehaviourSection(listing: listing),
        PriceHistorySection(listing: listing),
        NewPriceCard(listing: listing),
        if (listing.askingPrice case final asking?)
          ImportCostCard(
            key: ValueKey(listing.id),
            estimate: asking,
            against: ImportComparison.listing,
            year: listing.year,
            mileage: listing.mileage,
            engineCc: listing.engineCc,
            folded: true,
          ),
        OwnershipCostCard(listing: listing),
      ],
      _Section.details => [
        FactsCard(
          title: context.strings.bike,
          facts: bikeFacts(listing, language: context.language),
        ),
        if (description != null && description.isNotEmpty)
          _DescriptionCard(description: description),
        FactsCard(
          title: context.strings.listingListingDetailPage,
          facts: adFacts(listing, language: context.language),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                key: _listKey,
                controller: _scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final photo = PhotoGallery(
                        listingId: listing.id,
                        images: listing.images,
                      );
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(listing: listing, nameKey: _nameKey),
                          const SizedBox(height: 16),
                          ..._statusCards(context),
                          FavouriteNoteCard(listingId: listing.id),
                        ],
                      );
                      if (constraints.maxWidth >= 800) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: photo),
                            const SizedBox(width: 28),
                            Expanded(flex: 4, child: summary),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [photo, const SizedBox(height: 24), summary],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  DefaultTabController(
                    length: _Section.values.length,
                    initialIndex: _section.index,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        for (final section in _Section.values)
                          Tab(text: section.label(language: context.language)),
                      ],
                      onTap: (index) => _select(_Section.values[index]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final section in _Section.values)
                    if (_opened.contains(section))
                      Offstage(
                        offstage: section != _section,
                        child: TickerMode(
                          enabled: section == _section,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _cards(section),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        // Always in reach: the next step after reading is the seller's ad.
        // The tab bar's colour, which Safari's bottom toolbar is tinted with.
        Material(
          color: theme.colorScheme.surfaceContainerLowest,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final button = FilledButton.icon(
                          onPressed: () => _openOriginal(context),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            originalLinkLabel(
                              listing.source,
                              language: context.language,
                            ),
                          ),
                        );
                        final share = _ShareButton(listing: listing);
                        if (constraints.maxWidth < 600) {
                          return Row(
                            children: [
                              share,
                              const SizedBox(width: 12),
                              Expanded(child: button),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                listing.priceLabel(language: context.language),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFeatures: AppTheme.tabularFigures,
                                ),
                              ),
                            ),
                            share,
                            const SizedBox(width: 12),
                            button,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Removed, duplicate, relisted: shown before anything else, since they
  /// change how the rest reads.
  List<Widget> _statusCards(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastSeenAt = listing.lastSeenAt;
    final duplicateOf = listing.duplicateOf;
    return [
      if (listing.isRemoved)
        _StatusCard(
          color: scheme.errorContainer,
          icon: Icons.block,
          title: context.strings.listingRemovedListingDetailPage,
          text: lastSeenAt == null
              ? context.strings.thisListingIsNoLongerAvailable
              : context.strings.thisListingIsNoLongerAvailableLastSeen(
                  daysago: Formatters.daysAgo(
                    lastSeenAt,
                    language: context.language,
                  ),
                ),
        ),
      if (duplicateOf != null)
        _StatusCard(
          color: scheme.secondaryContainer,
          icon: Icons.content_copy,
          title: context.strings.duplicateListing,
          text: context.strings.itAppearsToBeSameBikeAsAnother,
          actionLabel: context.strings.viewOriginal,
          onAction: () => context.push(
            AppRoutes.listingDetail(duplicateOf),
            extra: AppRoutes.fromList,
          ),
        ),
      if (relistText(listing, language: context.language) case final relist?)
        _StatusCard(
          color: scheme.secondaryContainer,
          icon: Icons.history,
          title: context.strings.relisted,
          text: relist,
          actionLabel: context.strings.viewEarlierListing,
          onAction: () => context.push(
            AppRoutes.listingDetail(listing.relistedFrom!),
            extra: AppRoutes.fromList,
          ),
        ),
    ];
  }
}

class const _Header({
  required final Listing listing,

  /// On the bike's name, so the page knows when it has scrolled away.
  required final Key nameKey,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final score = listing.dealScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sourceLabel(listing.source, language: context.language).toUpperCase(),
          style: AppTheme.eyebrow(context),
        ),
        const SizedBox(height: 8),
        Text(
          listing.name,
          key: nameKey,
          style: textTheme.headlineLarge?.copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              listing.priceLabel(language: context.language),
              style: textTheme.displaySmall?.copyWith(
                fontSize: 42,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            PriceChangeTag(listing: listing),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          keyFactsLine(listing, language: context.language),
          style: textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                DealScoreBadge(score: score, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ScoreExplainer.label(score, language: context.language),
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.strings.dealScore0To100,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class const _StatusCard({
  required final Color color,
  required final IconData icon,
  required final String title,
  required final String text,
  final String? actionLabel,
  final VoidCallback? onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(text),
        trailing: actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel)),
      ),
    );
  }
}

/// The seller's text, folded after a few lines: it is often long.
class const _DescriptionCard({required final String description})
    extends StatefulWidget {
  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  static const _foldedLines = 8;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return SectionCard(
      title: context.strings.description,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(text: widget.description, style: style),
              maxLines: _foldedLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            final foldable = painter.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: style,
                  maxLines: _expanded || !foldable ? null : _foldedLines,
                  overflow: _expanded || !foldable
                      ? null
                      : TextOverflow.ellipsis,
                ),
                if (foldable)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? context.strings.showLess
                          : context.strings.showAll,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sends the ad to someone: the app's page of it, with the bike, its price
/// and the seller's ad (F.4). Where there is no share sheet, it is copied.
class const _ShareButton({required final Listing listing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.strings.shareListing,
    child: OutlinedButton(
      onPressed: () => shareOrCopy(
        ScaffoldMessenger.of(context),
        title: listing.nameAndYear,
        text: listingShareText(listing, language: context.language),
        url: listingLink(webOrigin, listing.id),
        language: context.language,
      ),
      child: const Icon(Icons.ios_share),
    ),
  );
}

/// Adds the listing to the comparison or takes it out; offers to open the
/// comparison once there are two or more.
class const _CompareButton({required final String listingId})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = getIt<CompareCubit>();
    return BlocBuilder<CompareCubit, List<String>>(
      bloc: cubit,
      builder: (context, compared) {
        final added = compared.contains(listingId);
        return IconButton(
          tooltip: added
              ? context.strings.removeFromComparison
              : context.strings.compare,
          isSelected: added,
          icon: const Icon(Icons.compare_arrows),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar();
            if (!cubit.toggle(listingId)) {
              showMessage(
                messenger,
                context.strings.compareFull(
                  maxCompared: (maxCompared).toString(),
                ),
              );
              return;
            }
            final now = cubit.state;
            if (added) {
              showMessage(messenger, context.strings.removedFromComparison);
            } else if (now.length < 2) {
              showMessage(messenger, context.strings.compareAddedChooseAnother);
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    context.strings.inComparison(length: now.length.toString()),
                  ),
                  action: SnackBarAction(
                    label: context.strings.compare,
                    onPressed: () => context.push(AppRoutes.compare(now)),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
