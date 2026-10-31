import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_brand.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../settings/presentation/home_place_cubit.dart';
import '../../../settings/presentation/home_place_tile.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/entities/saved_search.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../cubit/saved_searches_state.dart';
import '../dashboard_text.dart';
import '../listing_labels.dart';
import '../saved_search_summary.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/listing_card.dart';
import '../widgets/listing_card_skeleton.dart';
import '../widgets/save_search_dialog.dart';
import '../../../../core/localization/localizations.dart';

class const DashboardPage({super.key}) extends StatelessWidget {
  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<ListingsCubit>();
    final result = await showModalBottomSheet<ListingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => FiltersSheet(
        initial: cubit.state.filters,
        motorcycles: cubit.state.motorcycles,
      ),
    );
    if (result != null) unawaited(cubit.applyFilters(result));
  }

  Future<void> _saveSearch(BuildContext context) async {
    final messageStrings = context.strings;
    final messageLanguage = context.language;

    final state = context.read<ListingsCubit>().state;
    final filters = state.filters;
    final messenger = ScaffoldMessenger.of(context);
    final searches = getIt<SavedSearchesCubit>();

    // The list loads with the Pesquisas tab: without it the same search
    // could be saved again.
    if (searches.state.status != .success) {
      await searches.load();
    }
    if (savedSearchLike(searches.state.searches, filters) case final same?) {
      showMessage(messenger, alreadySavedText(same, language: messageLanguage));
      return;
    }
    if (!context.mounted) return;

    final name = await showSaveSearchDialog(
      context,
      suggestion: summarizeFilters(
        filters,
        state.motorcycles,
        language: messageLanguage,
      ),
    );
    if (name == null) return;

    final saved = await searches.create(name, filters);
    showMessage(
      messenger,
      saved ? messageStrings.searchSaved : messageStrings.couldNotSaveSearch,
    );
  }

  void _toggleCompare(BuildContext context, String id) {
    if (!getIt<CompareCubit>().toggle(id)) {
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      showMessage(
        messenger,
        context.strings.compareFull(maxCompared: (maxCompared).toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: BlocBuilder<CompareCubit, List<String>>(
        bloc: getIt<CompareCubit>(),
        builder: (context, compared) {
          if (compared.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            icon: const Icon(Icons.compare_arrows),
            label: Text(
              context.strings.compareDashboardPage(
                length: compared.length.toString(),
              ),
            ),
            onPressed: () {
              if (compared.length >= 2) {
                context.push(AppRoutes.compare(compared));
                return;
              }
              final messenger = ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar();
              showMessage(
                messenger,
                context.strings.tapCompareOnAnotherListingToAddIt,
              );
            },
          );
        },
      ),
      appBar: AppBar(
        title: MediaQuery.sizeOf(context).width < 840
            ? LayoutBuilder(
                builder: (context, constraints) => AppBrand(
                  compact:
                      constraints.maxWidth < 200 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20,
                ),
              )
            : Text(context.strings.deals),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.star_border),
            label: Text(context.strings.favourites),
            onPressed: () => context.push(AppRoutes.favourites),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _OffersScroll(
        builder: (context, scroll) => BlocBuilder<ListingsCubit, ListingsState>(
          builder: (context, state) {
            final cubit = context.read<ListingsCubit>();
            final chips = filterChips(
              state.filters,
              state.motorcycles,
              language: context.language,
            );
            final loading =
                state.status == .initial || state.status == .loading;

            final list = RefreshIndicator(
              onRefresh: cubit.load,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0 &&
                      notification.metrics.axis == Axis.vertical &&
                      notification.metrics.extentAfter < 800) {
                    Future.microtask(cubit.loadMore);
                  }
                  return false;
                },
                child: CustomScrollView(
                  key: ValueKey((state.filters, state.sort)),
                  controller: scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Opened several times a day: the intro only
                            // welcomes an empty list, the ads start at once.
                            if (state.status == .success &&
                                state.listings.isEmpty &&
                                state.filters.appliedCount == 0) ...[
                              PageIntro(
                                eyebrow: context.strings.yourMotorcycleRadar,
                                title: context.strings.yourNextBikeStartsHere,
                                description: context.strings.dealsIntro,
                              ),
                              const SizedBox(height: 24),
                            ],
                            _OffersToolbar(
                              state: state,
                              onFilters: () => _openFilters(context),
                            ),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (final chip in chips)
                                    InputChip(
                                      label: Text(chip.label),
                                      onDeleted: () =>
                                          cubit.applyFilters(chip.without),
                                      deleteButtonTooltipMessage:
                                          context.strings.removeFilter,
                                    ),
                                  if (chips.length > 1)
                                    ActionChip(
                                      label: Text(context.strings.clearAll),
                                      onPressed: () => cubit.applyFilters(
                                        ListingFilters.empty,
                                      ),
                                    ),
                                  // Saving belongs to the chosen filters:
                                  // without a criterion there is nothing
                                  // to save.
                                  if (state.filters.hasCriteria)
                                    BlocBuilder<
                                      SavedSearchesCubit,
                                      SavedSearchesState
                                    >(
                                      bloc: getIt<SavedSearchesCubit>(),
                                      builder: (context, searches) =>
                                          _SaveSearchButton(
                                            saved: savedSearchLike(
                                              searches.searches,
                                              state.filters,
                                            ),
                                            onSave: () => _saveSearch(context),
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (loading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: _OffersGrid(
                          itemCount: 6,
                          itemBuilder: (_, _) => const ListingCardSkeleton(),
                        ),
                      )
                    else if (state.status == .failure)
                      SliverFillRemaining(
                        child: StateMessage(
                          icon: Icons.cloud_off,
                          title: context.strings.couldNotLoadDeals,
                          message:
                              context.strings.checkYourConnectionAndTryAgain,
                          actionLabel: context.strings.retry,
                          onAction: cubit.load,
                        ),
                      )
                    else if (state.listings.isEmpty)
                      SliverFillRemaining(
                        child: StateMessage(
                          icon: Icons.search_off,
                          title: state.filters.appliedCount > 0
                              ? context.strings.noListingsMatchTheseFilters
                              : context.strings.noListingsYet,
                          message: state.filters.appliedCount > 0
                              ? context.strings.tryWideningYourSearchCriteria
                              : context
                                    .strings
                                    .chooseModelsYouWantToFollowOrCome,
                          actionLabel: state.filters.appliedCount > 0
                              ? context.strings.clearFilters
                              : context.strings.chooseModels,
                          onAction: state.filters.appliedCount > 0
                              ? () => cubit.applyFilters(ListingFilters.empty)
                              : () {
                                  unawaited(
                                    context
                                        .push<void>(AppRoutes.models)
                                        .then((_) => cubit.load()),
                                  );
                                },
                        ),
                      )
                    else
                      BlocBuilder<
                        ListingCardPreferencesCubit,
                        ListingCardPreferencesState
                      >(
                        bloc: getIt<ListingCardPreferencesCubit>(),
                        builder: (context, cards) => SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: _OffersGrid(
                            preferences: cards.preferences,
                            itemCount: state.listings.length,
                            itemBuilder: (context, index) {
                              final listing = state.listings[index];
                              return BlocBuilder<
                                FavouritesCubit,
                                FavouritesState
                              >(
                                bloc: getIt<FavouritesCubit>(),
                                buildWhen: (previous, current) =>
                                    previous.isFavourite(listing.id) !=
                                    current.isFavourite(listing.id),
                                builder: (context, favourites) =>
                                    // Only this card's pick: another
                                    // card's doesn't rebuild it.
                                    BlocSelector<
                                      CompareCubit,
                                      List<String>,
                                      bool
                                    >(
                                      bloc: getIt<CompareCubit>(),
                                      selector: (compared) =>
                                          compared.contains(listing.id),
                                      builder: (context, selected) =>
                                          ListingCard(
                                            listing: listing,
                                            preferences: cards.preferences,
                                            selected: selected,
                                            favourite: favourites.isFavourite(
                                              listing.id,
                                            ),
                                            onTap: () => context.push(
                                              AppRoutes.listingDetail(
                                                listing.id,
                                              ),
                                              extra: AppRoutes.fromList,
                                            ),
                                            onLongPress: () => _toggleCompare(
                                              context,
                                              listing.id,
                                            ),
                                          ),
                                    ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (state.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              ),
            );
            if (state.newCount == 0 || state.status != .success) return list;
            return Stack(
              children: [
                list,
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: _NewListingsPill(
                      count: state.newCount,
                      onTap: () {
                        if (scroll.hasClients) scroll.jumpTo(0);
                        unawaited(cubit.load());
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keeps Ofertas' scroll position in one controller across the list's
/// rebuilds, so the new-ads pill can bring it back to the top.
class const _OffersScroll({
  required final Widget Function(BuildContext, ScrollController) builder,
}) extends StatefulWidget {
  @override
  State<_OffersScroll> createState() => _OffersScrollState();
}

class _OffersScrollState extends State<_OffersScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// "3 anúncios novos" over the top of Ofertas, on return to the app once
/// the list is a while old (F.7): a tap shows them.
class const _NewListingsPill({
  required final int count,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.strings.showNewListings,
    child: FilledButton.icon(
      icon: const Icon(Icons.arrow_upward, size: 18),
      label: Text(
        context.strings.newListingsSinceLoad(count: count),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: onTap,
    ),
  );
}

/// Applies [sort]; "Mais perto" without a home first asks for one, and
/// stays unapplied if none was set.
Future<void> _applySort(BuildContext context, ListingSort sort) async {
  final listings = context.read<ListingsCubit>();
  if (sort == .nearest &&
      getIt<HomePlaceCubit>().state.noHome &&
      !await pickHomePlace(context)) {
    return;
  }
  await listings.applySort(sort);
}

/// Filtros, the sort and the count, on one row where they fit (most
/// phones: the count then takes a short line of its own).
class const _OffersToolbar({
  required final ListingsState state,
  required final VoidCallback onFilters,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onFilters,
            icon: Badge(
              isLabelVisible: state.filters.appliedCount > 0,
              label: Text('${state.filters.appliedCount}'),
              child: const Icon(Icons.tune, size: 18),
            ),
            label: Text(context.strings.filters),
          ),
          PopupMenuButton<ListingSort>(
            tooltip: context.strings.sort,
            initialValue: state.sort,
            onSelected: (sort) => unawaited(_applySort(context, sort)),
            itemBuilder: (localizationContext) {
              // Without a home no listing has a distance: "Mais perto"
              // says so, and picking it asks for the home first.
              final noHome = getIt<HomePlaceCubit>().state.noHome;
              return [
                for (final sort in ListingSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == state.sort,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sort.label(language: localizationContext.language),
                        ),
                        if (sort == .nearest && noHome)
                          Text(
                            localizationContext.strings.nearestNeedsHome,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ];
            },
            child: Container(
              constraints: BoxConstraints(
                minHeight: 48,
                maxWidth: constraints.maxWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      state.sort.label(language: context.language),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (state.status == .success && state.listings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                listingsResultsText(
                  state.listings.length,
                  hasMore: state.hasMore,
                  language: context.language,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Guardar pesquisa", or "Pesquisa guardada" (opens Pesquisas) when these
/// filters already are the saved search [saved].
class const _SaveSearchButton({
  required final SavedSearch? saved,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => saved == null
      ? TextButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(context.strings.saveSearch),
        )
      : TextButton.icon(
          onPressed: () => context.go(AppRoutes.searches),
          icon: const Icon(Icons.bookmark_added, size: 18),
          label: Text(context.strings.searchSaved),
        );
}

class const _OffersGrid({
  required final int itemCount,
  required final IndexedWidgetBuilder itemBuilder,
  final ListingCardPreferences preferences =
      const ListingCardPreferences.defaults(),
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = ((constraints.crossAxisExtent + 16) / 316).floor().clamp(
        1,
        3,
      );
      // Natural-height cards keep enlarged text readable instead of clipping
      // it into a fixed grid cell.
      if (columns == 1 || MediaQuery.textScalerOf(context).scale(16) > 20) {
        return SliverList.separated(
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
        );
      }
      return SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: ListingCard.gridHeight(
            context,
            preferences: preferences,
          ),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    },
  );
}
