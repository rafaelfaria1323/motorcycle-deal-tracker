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
import '../../domain/entities/alert_filter.dart';
import '../../domain/entities/listing_alert.dart';
import '../alerts_text.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';
import '../../../saved_searches/presentation/cubit/saved_searches_cubit.dart';
import '../widgets/alerts_segments.dart';
import '../../../saved_searches/presentation/widgets/edit_saved_search_sheet.dart';
import '../../../../core/localization/localizations.dart';

class const AlertsPage({super.key}) extends StatelessWidget {
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
    if (searches.state.status != .success) {
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

  Future<void> _deleteRead(BuildContext context) async {
    final messageStrings = context.strings;

    final cubit = context.read<AlertsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(
      context,
      title: messageStrings.deleteReadAlertsQuestion,
      message: messageStrings.deleteReadAlertsMessage,
    )) {
      return;
    }
    final deleted = await cubit.dismissRead();
    if (messenger.mounted) {
      showMessage(messenger, switch (deleted) {
        null => messageStrings.couldNotDeleteReadAlerts,
        0 => messageStrings.noReadAlertsToDelete,
        final int count => messageStrings.readAlertsDeleted(count: count),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          BlocBuilder<AlertsCubit, AlertsState>(
            buildWhen: (previous, current) =>
                _canDeleteRead(previous) != _canDeleteRead(current),
            builder: (context, state) => IconButton(
              tooltip: context.strings.deleteReadAlerts,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _canDeleteRead(state)
                  ? () => _deleteRead(context)
                  : null,
            ),
          ),
          IconButton(
            tooltip: context.strings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AlertsCubit>().load(),
          ),
        ],
      ),
      body: AlertsSegments(
        searches: false,
        child: BlocBuilder<AlertsCubit, AlertsState>(
          builder: (context, state) {
            // With a filter chosen the chips stay, to choose another.
            if (state.filter == AlertFilter.all) {
              if (state.status == .initial || state.status == .loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == .failure) {
                return StateMessage(
                  icon: Icons.cloud_off,
                  title: context.strings.couldNotLoadAlerts,
                  message: context.strings.checkYourConnectionAndTryAgain,
                  actionLabel: context.strings.retry,
                  onAction: () => context.read<AlertsCubit>().load(),
                );
              }
              if (state.alerts.isEmpty) {
                return StateMessage(
                  icon: Icons.notifications_none,
                  title: context.strings.youHaveNoAlertsYet,
                  message: context.strings.saveSearchAndWeWillLetYouKnow,
                  actionLabel: context.strings.viewSearches,
                  onAction: () => context.go(AppRoutes.searches),
                );
              }
            }
            return _list(context, state);
          },
        ),
      ),
    );
  }

  static bool _canDeleteRead(AlertsState state) =>
      state.status == .success && state.mayHaveRead;

  Widget _list(BuildContext context, AlertsState state) {
    final theme = Theme.of(context);
    final cubit = context.read<AlertsCubit>();

    return RefreshIndicator(
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
                _FilterChips(
                  selected: state.filter,
                  onSelected: cubit.applyFilter,
                ),
                ...switch (state.status) {
                  .initial || .loading => [
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  .failure => [
                    _FilterNote(
                      text: context.strings.couldNotLoadAlerts,
                      actionLabel: context.strings.retry,
                      onAction: cubit.load,
                    ),
                  ],
                  .success when state.alerts.isEmpty => [
                    _FilterNote(
                      text: context.strings.noAlertsOfThisKind,
                      actionLabel: context.strings.showAllAlerts,
                      onAction: () => cubit.applyFilter(AlertFilter.all),
                    ),
                  ],
                  .success => [
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
                          title: alertTitle(alert, language: context.language),
                          icon: _icon(alert.type),
                          onTap: () => _open(context, alert),
                          onEdit: alert.searchId == null
                              ? null
                              : () => _edit(context, alert),
                          onDelete: () => _delete(context, alert),
                        ),
                    ],
                  ],
                },
                if (state.loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alertas' kinds (F.6), one chosen at a time; they wrap on a narrow phone.
class const _FilterChips({
  required final AlertFilter selected,
  required final ValueChanged<AlertFilter> onSelected,
}) extends StatelessWidget {
  static String _label(BuildContext context, AlertFilter filter) =>
      switch (filter) {
        .all => context.strings.all,
        .newListings => context.strings.alertFilterNew,
        .priceDrops => context.strings.priceDrops,
        .excellent => context.strings.alertFilterExcellent,
        .removed => context.strings.alertFilterRemoved,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in AlertFilter.values)
          ChoiceChip(
            label: Text(_label(context, filter)),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

/// Under the chips: no alerts of the chosen kind, or they could not load.
class const _FilterNote({
  required final String text,
  required final String actionLabel,
  required final VoidCallback onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

enum _AlertAction { edit, delete }

class const _AlertTile({
  required final ListingAlert alert,
  required final String title,
  required final IconData icon,
  required final VoidCallback onTap,
  required final Future<void> Function() onDelete,
  final Future<void> Function()? onEdit,
  super.key,
}) extends StatelessWidget {
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
                                  localizationContext.strings.deleteAlertAction,
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
