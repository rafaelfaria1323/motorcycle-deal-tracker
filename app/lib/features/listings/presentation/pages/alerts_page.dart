import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
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
import '../../../../core/localization/localizations.dart';

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
    final messageStrings = context.strings;

    final searches = getIt<SavedSearchesCubit>();
    final alerts = context.read<AlertsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await searches.load();
    if (!context.mounted) return;
    if (searches.state.status != SavedSearchesStatus.success) {
      showMessage(messenger, messageStrings.couldNotLoadThisAlertSSearch);
      return;
    }
    final search = searches.state.searches
        .where((search) => search.id == alert.searchId)
        .firstOrNull;
    if (search == null) {
      showMessage(messenger, messageStrings.thisAlertSSearchNoLongerExists);
      return;
    }
    if (await editSavedSearch(context, search: search, cubit: searches)) {
      await alerts.load();
    }
  }

  Future<void> _delete(BuildContext context, ListingAlert alert) async {
    final messageStrings = context.strings;

    final cubit = context.read<AlertsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(
      context,
      title: messageStrings.deleteAlert,
      message: messageStrings.thisAlertWillBeRemovedFromYourList,
    )) {
      return;
    }
    final deleted = await cubit.dismiss(alert.id);
    if (messenger.mounted) {
      showMessage(
        messenger,
        deleted
            ? messageStrings.alertDeleted
            : messageStrings.couldNotDeleteAlert,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.alerts),
        actions: [
          BlocBuilder<AlertsCubit, AlertsState>(
            buildWhen: (previous, current) =>
                previous.unreadCount != current.unreadCount,
            builder: (context, state) => IconButton(
              tooltip: context.strings.markAllAsRead,
              icon: const Icon(Icons.done_all),
              onPressed: state.unreadCount == 0
                  ? null
                  : () => context.read<AlertsCubit>().markAllRead(),
            ),
          ),
          IconButton(
            tooltip: context.strings.refresh,
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
                title: context.strings.couldNotLoadAlerts,
                message: context.strings.checkYourConnectionAndTryAgain,
                actionLabel: context.strings.retry,
                onAction: () => context.read<AlertsCubit>().load(),
              );
            case AlertsStatus.success:
              if (state.alerts.isEmpty) {
                return StateMessage(
                  icon: Icons.notifications_none,
                  title: context.strings.youHaveNoAlertsYet,
                  message: context.strings.saveSearchAndWeWillLetYouKnow,
                  actionLabel: context.strings.viewSearches,
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
                        PageIntro(
                          eyebrow: context.strings.alerts,
                          title: context.strings.whatChanged,
                          description: context.strings.alertsIntro,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          unreadAlertsText(
                            state.unreadCount,
                            language: context.language,
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: state.unreadCount > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final day in groupAlertsByDay(
                          state.alerts,
                          language: context.language,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Row(
                              children: [
                                Text(
                                  day.label.toUpperCase(),
                                  style: AppTheme.groupLabel(context),
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
                              title: alertTitle(
                                alert,
                                language: context.language,
                              ),
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
                                label: context.strings.unread,
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
                            tooltip: context.strings.alertOptions,
                            onSelected: (action) => switch (action) {
                              _AlertAction.edit => onEdit?.call(),
                              _AlertAction.delete => onDelete(),
                            },
                            itemBuilder: (localizationContext) => [
                              if (onEdit != null)
                                PopupMenuItem(
                                  value: _AlertAction.edit,
                                  child: Text(
                                    localizationContext.strings.editSearch,
                                  ),
                                ),
                              PopupMenuItem(
                                value: _AlertAction.delete,
                                child: Text(
                                  localizationContext
                                      .strings
                                      .deleteAlertAlertsPage,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alertDetailsLine(alert, language: context.language),
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
