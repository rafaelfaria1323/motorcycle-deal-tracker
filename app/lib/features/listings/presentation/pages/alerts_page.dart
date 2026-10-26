import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/confirm_delete.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../../core/widgets/swipe_actions.dart';
import '../../domain/entities/listing_alert.dart';
import '../alerts_text.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../cubit/saved_searches_state.dart';
import '../widgets/edit_saved_search_sheet.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static IconData _icon(AlertType type) => switch (type) {
    AlertType.newListing => Icons.fiber_new_outlined,
    AlertType.priceReduction => Icons.trending_down,
    AlertType.excellentOpportunity => Icons.local_fire_department_outlined,
    AlertType.listingRemoved => Icons.block,
    AlertType.backOnMarket => Icons.replay,
    AlertType.targetPriceReached => Icons.flag_outlined,
    AlertType.unknown => Icons.notifications_none,
  };

  void _open(BuildContext context, ListingAlert alert) {
    context.read<AlertsCubit>().markRead(alert.id);
    context.push(AppRoutes.listingDetail(alert.listing.id));
  }

  Future<void> _edit(BuildContext context, ListingAlert alert) async {
    final searches = getIt<SavedSearchesCubit>();
    final alerts = context.read<AlertsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await searches.load();
    if (!context.mounted) return;
    if (searches.state.status != SavedSearchesStatus.success) {
      showMessage(
        messenger,
        'Não foi possível carregar a pesquisa deste alerta',
      );
      return;
    }
    final search = searches.state.searches
        .where((search) => search.id == alert.searchId)
        .firstOrNull;
    if (search == null) {
      showMessage(messenger, 'A pesquisa deste alerta já não existe');
      return;
    }
    if (await editSavedSearch(context, search: search, cubit: searches)) {
      await alerts.load();
    }
  }

  Future<void> _delete(BuildContext context, ListingAlert alert) async {
    final cubit = context.read<AlertsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(
      context,
      title: 'Eliminar alerta?',
      message:
          'Este alerta será eliminado da sua lista. '
          'A pesquisa e os restantes alertas não serão alterados.',
    )) {
      return;
    }
    final deleted = await cubit.dismiss(alert.id);
    if (messenger.mounted) {
      showMessage(
        messenger,
        deleted ? 'Alerta eliminado' : 'Não foi possível eliminar o alerta',
      );
    }
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
                      'Guarde uma pesquisa e avisamos quando surgir um anúncio novo.',
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        const PageIntro(
                          eyebrow: 'Alertas',
                          title: 'O que mudou',
                          description:
                              'Novos anúncios, baixas de preço e novidades '
                              'das motas que acompanha. Deslize para a esquerda '
                              'para eliminar ou para a direita para editar '
                              'a pesquisa de origem.',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          unreadAlertsText(state.unreadCount),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: state.unreadCount > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final day in groupAlertsByDay(state.alerts)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Row(
                              children: [
                                Text(
                                  day.label.toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          for (final alert in day.alerts)
                            _AlertTile(
                              key: ValueKey(alert.id),
                              alert: alert,
                              title: alertTitle(alert),
                              icon: _icon(alert.type),
                              onTap: () => _open(context, alert),
                              onEdit: alert.searchId == null
                                  ? null
                                  : () => _edit(context, alert),
                              onDelete: () => _delete(context, alert),
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

enum _AlertAction { edit, delete }

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
    super.key,
  });

  final ListingAlert alert;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

    // Good news in green, a removal in grey, the rest in the accent.
    final (Color background, Color foreground) = switch (alert.type) {
      AlertType.priceReduction ||
      AlertType.excellentOpportunity ||
      AlertType.targetPriceReached => (
        colors.positive.withValues(alpha: 0.14),
        colors.positive,
      ),
      AlertType.listingRemoved || AlertType.unknown => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      AlertType.newListing || AlertType.backOnMarket => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: SwipeActions(
        id: alert.id,
        onEdit: onEdit,
        onDelete: onDelete,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: foreground),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: alert.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!alert.isRead) ...[
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Semantics(
                                label: 'Não lido',
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          PopupMenuButton<_AlertAction>(
                            tooltip: 'Opções do alerta',
                            onSelected: (action) => switch (action) {
                              _AlertAction.edit => onEdit?.call(),
                              _AlertAction.delete => onDelete(),
                            },
                            itemBuilder: (_) => [
                              if (onEdit != null)
                                const PopupMenuItem(
                                  value: _AlertAction.edit,
                                  child: Text('Editar pesquisa'),
                                ),
                              const PopupMenuItem(
                                value: _AlertAction.delete,
                                child: Text('Eliminar alerta'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alertDetailsLine(alert),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alertOriginLine(alert),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
