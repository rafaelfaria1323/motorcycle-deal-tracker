import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../widgets/listing_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas')),
      body: BlocBuilder<ListingsCubit, ListingsState>(
        builder: (context, state) {
          switch (state.status) {
            case ListingsStatus.initial:
            case ListingsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ListingsStatus.failure:
              return const Center(child: Text('Erro ao carregar ofertas'));
            case ListingsStatus.success:
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 290,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.listings.length,
                itemBuilder: (context, index) => ListingCard(listing: state.listings[index]),
              );
          }
        },
      ),
    );
  }
}
