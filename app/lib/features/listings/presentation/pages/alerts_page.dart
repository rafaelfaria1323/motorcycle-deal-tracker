import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing_alert.dart';
import '../alerts_text.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static IconData _icon(AlertType type) => switch (type) {
    AlertType.newListing => Icons.fiber_new_outlined,
    AlertType.priceReduction => Icons.trending_down,
    AlertType.excellentOpportunity => Icons.local_fire_department_outlined,
    AlertType.listingRemoved => Icons.block,
    AlertType.unknown => Icons.notifications_none,
  };

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
                  message: 'Guarde uma pesquisa e avisamos quando surgir uma oferta nova.',
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
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final day in groupAlertsByDay(state.alerts)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Text(
                              day.label.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          for (final alert in day.alerts)
                            _AlertTile(
                              alert: alert,
                              title: alertTitle(alert),
                              icon: _icon(alert.type),
                              onTap: () => _open(context, alert),
                            ),
                        ],
                      ],
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

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final ListingAlert alert;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

    // Good news in green, a removal in grey, the rest in the accent.
    final (Color background, Color foreground) = switch (alert.type) {
      AlertType.priceReduction || AlertType.excellentOpportunity => (
        colors.positive.withValues(alpha: 0.14),
        colors.positive,
      ),
      AlertType.listingRemoved || AlertType.unknown => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      AlertType.newListing => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: background,
          foregroundColor: foreground,
          child: Icon(icon, size: 22),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Text('${alertDetailsLine(alert)}\n${alertOriginLine(alert)}'),
        trailing: alert.isRead
            ? null
            : Semantics(
                label: 'Não lido',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
