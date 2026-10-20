import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../listing_labels.dart';
import '../saved_search_summary.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/listing_card.dart';
import '../widgets/listing_card_skeleton.dart';
import '../widgets/save_search_dialog.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 420,
    mainAxisExtent: ListingCard.height,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  );

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
    if (result != null) cubit.applyFilters(result);
  }

  Future<void> _saveSearch(BuildContext context) async {
    final state = context.read<ListingsCubit>().state;
    final filters = state.filters;
    final messenger = ScaffoldMessenger.of(context);

    if (!filters.hasCriteria) {
      showMessage(
        messenger,
        'Escolha pelo menos um filtro antes de guardar.',
      );
      return;
    }

    final name = await showSaveSearchDialog(
      context,
      suggestion: summarizeFilters(filters, state.motorcycles),
    );
    if (name == null) return;

    final saved = await getIt<SavedSearchesCubit>().create(name, filters);
    showMessage(
      messenger,
      saved ? 'Pesquisa guardada' : 'Não foi possível guardar a pesquisa',
    );
  }

  void _toggleCompare(BuildContext context, String id) {
    if (!getIt<CompareCubit>().toggle(id)) {
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      showMessage(
        messenger,
        'Já tem $maxCompared anúncios na comparação. Retire um primeiro.',
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
            label: Text('Comparar (${compared.length})'),
            onPressed: () {
              if (compared.length >= 2) {
                context.push(AppRoutes.compare(compared));
                return;
              }
              final messenger = ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar();
              showMessage(
                messenger,
                'Mantenha premido outro anúncio para o comparar.',
              );
            },
          );
        },
      ),
      appBar: AppBar(
        title: const Text('Ofertas'),
        actions: [
          BlocBuilder<ListingsCubit, ListingsState>(
            buildWhen: (previous, current) => previous.sort != current.sort,
            builder: (context, state) => PopupMenuButton<ListingSort>(
              tooltip: 'Ordenar',
              icon: const Icon(Icons.sort),
              initialValue: state.sort,
              onSelected: context.read<ListingsCubit>().applySort,
              itemBuilder: (_) => [
                for (final sort in ListingSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == state.sort,
                    child: Text(sort.label),
                  ),
              ],
            ),
          ),
          BlocBuilder<ListingsCubit, ListingsState>(
            buildWhen: (previous, current) =>
                previous.filters != current.filters,
            builder: (context, state) => IconButton(
              tooltip: 'Filtros',
              icon: Badge(
                isLabelVisible: state.filters.appliedCount > 0,
                label: Text('${state.filters.appliedCount}'),
                child: const Icon(Icons.tune),
              ),
              onPressed: () => _openFilters(context),
            ),
          ),
          IconButton(
            tooltip: 'Guardar pesquisa',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _saveSearch(context),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<ListingsCubit, ListingsState>(
            buildWhen: (previous, current) =>
                previous.filters != current.filters ||
                previous.motorcycles != current.motorcycles,
            builder: (context, state) {
              final chips = filterChips(state.filters, state.motorcycles);
              if (chips.isEmpty) return const SizedBox.shrink();
              final cubit = context.read<ListingsCubit>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(chip.label),
                          onDeleted: () => cubit.applyFilters(chip.without),
                          deleteButtonTooltipMessage: 'Remover filtro',
                        ),
                      ),
                    if (chips.length > 1)
                      ActionChip(
                        label: const Text('Limpar tudo'),
                        onPressed: () =>
                            cubit.applyFilters(ListingFilters.empty),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: BlocBuilder<ListingsCubit, ListingsState>(
              builder: (context, state) {
                switch (state.status) {
                  case ListingsStatus.initial:
                  case ListingsStatus.loading:
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: _grid,
                      itemCount: 6,
                      itemBuilder: (_, _) => const ListingCardSkeleton(),
                    );
                  case ListingsStatus.failure:
                    return StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Não foi possível carregar as ofertas',
                      message: 'Verifique a ligação e tente novamente.',
                      actionLabel: 'Tentar novamente',
                      onAction: () => context.read<ListingsCubit>().load(),
                    );
                  case ListingsStatus.success:
                    if (state.listings.isEmpty) {
                      final hasFilters = state.filters.appliedCount > 0;
                      return StateMessage(
                        icon: Icons.search_off,
                        title: hasFilters
                            ? 'Nenhuma oferta com estes filtros'
                            : 'Ainda não há ofertas',
                        message: hasFilters
                            ? 'Experimente alargar os critérios de pesquisa.'
                            : 'Volte mais tarde, estamos a acompanhar o mercado.',
                        actionLabel: hasFilters ? 'Limpar filtros' : null,
                        onAction: hasFilters
                            ? () => context.read<ListingsCubit>().applyFilters(
                                ListingFilters.empty,
                              )
                            : null,
                      );
                    }

                    final cubit = context.read<ListingsCubit>();
                    return NotificationListener<ScrollNotification>(
                      // Asks for the next page a screen before the end.
                      onNotification: (notification) {
                        // Deferred: a notification can arrive mid-layout.
                        if (notification.metrics.extentAfter < 800) {
                          Future.microtask(cubit.loadMore);
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid.builder(
                              gridDelegate: _grid,
                              itemCount: state.listings.length,
                              itemBuilder: (context, index) {
                                final listing = state.listings[index];
                                return BlocBuilder<CompareCubit, List<String>>(
                                  bloc: getIt<CompareCubit>(),
                                  builder: (context, compared) => ListingCard(
                                    listing: listing,
                                    selected: compared.contains(listing.id),
                                    onTap: () => context.go(
                                      AppRoutes.listingDetail(listing.id),
                                    ),
                                    onLongPress: () =>
                                        _toggleCompare(context, listing.id),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (state.loadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
