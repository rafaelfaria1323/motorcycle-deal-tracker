import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';

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
              return ListView.separated(
                itemCount: state.listings.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final l = state.listings[index];
                  return ListTile(
                    title: Text('${l.brand} ${l.model} ${l.year ?? ''}'),
                    subtitle: Text('${l.mileage ?? '?'} km · ${l.location ?? '-'}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [Text('€${l.price?.toStringAsFixed(0) ?? '-'}'), Text('Score ${l.dealScore ?? '-'}')],
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
