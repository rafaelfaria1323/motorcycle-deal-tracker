import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../compare/presentation/widgets/compare_button.dart';
import '../../../favourites/presentation/widgets/favourite_widgets.dart';
import '../../../favourites/presentation/widgets/viewing_checklist_card.dart';
import '../../../market/presentation/widgets/market_behaviour_section.dart';
import '../../../valuation/presentation/import_cost_text.dart';
import '../../../valuation/presentation/widgets/import_cost_card.dart';
import '../../../valuation/presentation/widgets/ownership_cost_card.dart';
import '../../domain/entities/listing.dart';
import '../cubit/listing_detail_cubit.dart';
import '../cubit/listing_detail_state.dart';
import '../listing_detail_text.dart';
import '../widgets/also_listed_section.dart';
import '../widgets/dealer_card.dart';
import '../widgets/description_card.dart';
import '../widgets/facts_card.dart';
import '../widgets/listing_bottom_bar.dart';
import '../widgets/listing_header.dart';
import '../widgets/listing_status_cards.dart';
import '../widgets/new_price_card.dart';
import '../widgets/offer_card.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/photo_hints_card.dart';
import '../widgets/price_history_section.dart';
import '../widgets/score_explanation_card.dart';
import '../widgets/seller_message_card.dart';

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
                final listing? when hidden => ListingCompactTitle(
                  key: const ValueKey('compact'),
                  listing: listing,
                ),
                _ => Text(context.strings.theListing),
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
          CompareButton(listingId: listingId),
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
          DescriptionCard(description: description),
        FactsCard(
          title: context.strings.theListing,
          facts: adFacts(listing, language: context.language),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
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
                          ListingHeader(listing: listing, nameKey: _nameKey),
                          const SizedBox(height: 16),
                          ListingStatusCards(listing: listing),
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
        ListingBottomBar(listing: listing),
      ],
    );
  }
}
