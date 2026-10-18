import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing_alert.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static String _title(ListingAlert alert) {
    final listing = alert.listing;
    final bike = [
      '${listing.brand} ${listing.model}',
      if (listing.year != null) '${listing.year}',
    ].join(' · ');
    return switch (alert.type) {
      AlertType.newListing => 'Nova oferta: $bike',
      AlertType.priceReduction => 'Preço reduzido: $bike',
      AlertType.excellentOpportunity => 'Excelente oportunidade: $bike',
      AlertType.listingRemoved => 'Anúncio removido: $bike',
      AlertType.unknown => bike,
    };
  }

  void _open(BuildContext context, ListingAlert alert) {
    context.read<AlertsCubit>().markRead(alert.id);
    context.go(AppRoutes.listingDetail(alert.listing.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          BlocBuilder<AlertsCubit, AlertsState>(
            buildWhen: (previous, current) =>
                previous.unreadCount != current.unreadCount,
            builder: (context, state) => IconButton(
              tooltip: 'Marcar todos como lidos',
              icon: const Icon(Icons.done_all),
              onPressed: state.unreadCount == 0
                  ? null
                  : () => context.read<AlertsCubit>().markAllRead(),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AlertsCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<AlertsCubit, AlertsState>(
        builder: (context, state) {
          switch (state.status) {
            case AlertsStatus.initial:
            case AlertsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case AlertsStatus.failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: 'Não foi possível carregar os alertas',
                message: 'Verifique a ligação e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: () => context.read<AlertsCubit>().load(),
              );
            case AlertsStatus.success:
              if (state.alerts.isEmpty) {
                return StateMessage(
                  icon: Icons.notifications_none,
                  title: 'Ainda não tem alertas',
                  message:
                      'Guarde uma pesquisa e avisamos quando surgir uma oferta nova.',
                  actionLabel: 'Ver pesquisas',
                  onAction: () => context.go(AppRoutes.searches),
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<AlertsCubit>().load(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: state.alerts.length,
                      itemBuilder: (context, index) {
                        final alert = state.alerts[index];
                        final price = alert.newPrice ?? alert.listing.price;
                        final details = [
                          Formatters.price(price),
                          if (alert.listing.location != null)
                            alert.listing.location!,
                        ].join(' · ');
                        final origin = [
                          if (alert.searchName != null) '"${alert.searchName}"',
                          Formatters.daysAgo(alert.createdAt),
                        ].join(' · ');

                        return Card(
                          child: ListTile(
                            isThreeLine: true,
                            leading: const Icon(Icons.fiber_new_outlined),
                            title: Text(
                              _title(alert),
                              style: TextStyle(
                                fontWeight: alert.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('$details\n$origin'),
                            trailing: alert.isRead
                                ? null
                                : Semantics(
                                    label: 'Não lido',
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                            onTap: () => _open(context, alert),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
