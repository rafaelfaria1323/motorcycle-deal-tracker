import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/confirm_delete.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../../core/widgets/swipe_actions.dart';
import '../../domain/entities/alert_filter.dart';
import '../../domain/entities/listing_alert.dart';
import '../../../listings/presentation/listing_labels.dart';
import '../../../listings/presentation/widgets/deal_score_badge.dart';
import '../../../listings/presentation/photo_url.dart';
import '../../../listings/presentation/widgets/listing_photo.dart';
import '../../../listings/presentation/widgets/photo_tag.dart';
import '../alerts_text.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';
import '../../../saved_searches/presentation/cubit/saved_searches_cubit.dart';
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
      body: BlocBuilder<AlertsCubit, AlertsState>(
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
    );
  }

  static bool _canDeleteRead(AlertsState state) =>
      state.status == .success && state.mayHaveRead;

  Widget _list(BuildContext context, AlertsState state) {
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
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _UnreadBadge(count: state.unreadCount),
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

/// "3 alertas por ler" in the accent while some are unread, else "Tudo lido".
class const _UnreadBadge({required final int count}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = count > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: unread
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          unreadAlertsText(count, language: context.language),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: unread ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _AlertAction { edit, delete }

/// An alert as in the Stitch design: the ad's photo with its site, the kind
/// of alert in its colour and the time, the bike, its place and figures,
/// the prices (the earlier one struck out) and the Deal Score. A removed
/// ad is greyed out.
class const _AlertTile({
  required final ListingAlert alert,
  required final IconData icon,
  required final VoidCallback onTap,
  required final Future<void> Function() onDelete,
  final Future<void> Function()? onEdit,
  super.key,
}) extends StatelessWidget {
  /// The photo's side: smaller on a phone, so the text keeps its room.
  static double _photoSize(double width) => width < 400 ? 72 : 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final language = context.language;
    final listing = alert.listing;
    final gone = alert.type == AlertType.listingRemoved || listing.isRemoved;

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
    final kind = alertKindLabel(alert, language: language);
    final facts = alertFactsLine(listing, language: language);
    final prices = alertPrices(alert, language: language);
    final score = listing.dealScore;

    Widget photo(double size) => SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A small square: the smallest size is plenty at 3x.
            ListingPhoto(
              url: listing.images.firstOrNull,
              box: cardPhotoSteps.first,
            ),
            PositionedDirectional(
              start: 4,
              end: 4,
              bottom: 4,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: PhotoTag(
                  sourceLabel(listing.source, language: language),
                  strong: true,
                ),
              ),
            ),
            if (!alert.isRead)
              PositionedDirectional(
                top: 6,
                start: 6,
                child: Semantics(
                  label: context.strings.unread,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.surfaceContainerLowest,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (kind.isNotEmpty)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: foreground),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  kind.toUpperCase(),
                                  style: AppTheme.groupLabel(context)
                                      ?.copyWith(color: foreground),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      Formatters.time(alert.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    child: Text(localizationContext.strings.editSearch),
                  ),
                PopupMenuItem(
                  value: _AlertAction.delete,
                  child: Text(localizationContext.strings.deleteAlertAction),
                ),
              ],
            ),
          ],
        ),
        Text(
          listing.nameAndYear,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            facts,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  if (prices.before case final before?)
                    Text(
                      before,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  Text(
                    prices.now,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            if (score != null && !gone) ...[
              const SizedBox(width: 8),
              DealScoreBadge(score: score),
            ],
          ],
        ),
        if (alert.searchName case final search?) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.bookmark_border,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  search,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: SwipeActions(
        id: alert.id,
        onEdit: onEdit,
        onDelete: onDelete,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: gone ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 12),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: photo(_photoSize(constraints.maxWidth)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: details,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
