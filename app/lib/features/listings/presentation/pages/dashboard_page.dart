import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../domain/entities/listing_filters.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/listing_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<ListingsCubit>();
    final result = await showModalBottomSheet<ListingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => FiltersSheet(initial: cubit.state.filters, motorcycles: cubit.state.motorcycles),
    );
    if (result != null) cubit.applyFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
        actions: [
          BlocBuilder<ListingsCubit, ListingsState>(
            buildWhen: (previous, current) => previous.filters != current.filters,
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
        ],
      ),
      body: BlocBuilder<ListingsCubit, ListingsState>(
        builder: (context, state) {
          switch (state.status) {
            case ListingsStatus.initial:
            case ListingsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ListingsStatus.failure:
              return const Center(child: Text('Erro ao carregar ofertas'));
            case ListingsStatus.success:
              if (state.listings.isEmpty) {
                return const Center(child: Text('Nenhuma oferta encontrada'));
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 290,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.listings.length,
                itemBuilder: (context, index) {
                  final listing = state.listings[index];
                  return ListingCard(listing: listing, onTap: () => context.go(AppRoutes.listingDetail(listing.id)));
                },
              );
          }
        },
      ),
    );
  }
}
