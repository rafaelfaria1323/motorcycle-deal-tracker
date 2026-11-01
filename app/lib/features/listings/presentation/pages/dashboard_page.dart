import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/app_brand.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../compare/presentation/widgets/compare_fab.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../../domain/entities/listing_filters.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../widgets/deals_header.dart';
import '../widgets/deals_list_item.dart';
import '../widgets/listing_card.dart';
import '../widgets/listing_card_skeleton.dart';

class const DashboardPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const CompareFab(),
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
      ),
      body: _OffersScroll(
        builder: (context, scroll) => BlocBuilder<ListingsCubit, ListingsState>(
          builder: (context, state) {
            final cubit = context.read<ListingsCubit>();
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
                        child: DealsHeader(state: state),
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
                            itemBuilder: (context, index) => DealsListItem(
                              listing: state.listings[index],
                              preferences: cards.preferences,
                            ),
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
