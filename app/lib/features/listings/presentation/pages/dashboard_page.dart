import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../collector_status/presentation/collector_status_banner.dart';
import '../../domain/entities/listing_filters.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../saved_search_summary.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/listing_card.dart';
import '../widgets/save_search_dialog.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Escolha pelo menos um filtro antes de guardar.'),
        ),
      );
      return;
    }

    final name = await showSaveSearchDialog(
      context,
      suggestion: summarizeFilters(filters, state.motorcycles),
    );
    if (name == null) return;

    final saved = await getIt<SavedSearchesCubit>().create(name, filters);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Pesquisa guardada' : 'Não foi possível guardar a pesquisa',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
        actions: [
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CollectorStatusBanner(),
          ),
          Expanded(
            child: BlocBuilder<ListingsCubit, ListingsState>(
              builder: (context, state) {
                switch (state.status) {
                  case ListingsStatus.initial:
                  case ListingsStatus.loading:
                    return const Center(child: CircularProgressIndicator());
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
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 420,
                                    mainAxisExtent: 290,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: state.listings.length,
                              itemBuilder: (context, index) {
                                final listing = state.listings[index];
                                return ListingCard(
                                  listing: listing,
                                  onTap: () => context.go(
                                    AppRoutes.listingDetail(listing.id),
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
