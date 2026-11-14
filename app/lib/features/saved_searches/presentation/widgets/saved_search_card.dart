import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/swipe_actions.dart';
import '../../domain/entities/saved_search.dart';
import '../saved_search_summary.dart';

enum _SearchAction { edit, delete }

/// A saved search after Stitch's Pesquisas screen: its place and name,
/// how many ads it finds, which alerts it sends (a tap edits them), its
/// criteria as labelled chips, and when it was made beside "Ver
/// resultados". The whole card opens its results; swiping edits or
/// deletes it.
class const SavedSearchCard({
  required final SavedSearch search,
  required final int number,
  required final List<SearchCriterion> criteria,
  required final int matches,
  required final VoidCallback onTap,
  required final Future<void> Function() onEdit,
  required final Future<void> Function() onDelete,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = context.language;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwipeActions(
        id: search.id,
        onEdit: onEdit,
        onDelete: onDelete,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.strings
                                .searchNumber(number: '$number')
                                .toUpperCase(),
                            style: AppTheme.eyebrow(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            savedSearchName(search, language: language),
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_SearchAction>(
                      tooltip: context.strings.searchOptions,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (action) => switch (action) {
                        _SearchAction.edit => onEdit(),
                        _SearchAction.delete => onDelete(),
                      },
                      itemBuilder: (menuContext) => [
                        PopupMenuItem(
                          value: _SearchAction.edit,
                          child: Text(menuContext.strings.editSearch),
                        ),
                        PopupMenuItem(
                          value: _SearchAction.delete,
                          child: Text(menuContext.strings.deleteSearch),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        searchMatchesText(matches, language: language),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AlertsBox(search: search, onTap: onEdit),
                      if (criteria.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final criterion in criteria)
                              _CriterionChip(criterion),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              Text(
                                searchCreatedText(search, language: language),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              iconAlignment: IconAlignment.end,
                            ),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(context.strings.seeResults),
                          ),
                        ],
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

/// Which alerts the search sends, in a tinted box: the bell in the
/// accent colour when it sends any, crossed out when none. A tap opens
/// the editor, where they are chosen.
class const _AlertsBox({
  required final SavedSearch search,
  required final Future<void> Function() onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alerts =
        search.notifyNewListing ||
        search.notifyPriceReduction ||
        search.notifyExcellentDeal ||
        search.notifyListingRemoved;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            spacing: 10,
            children: [
              Icon(
                alerts
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                size: 20,
                color: alerts ? scheme.primary : scheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  searchNotificationText(search, language: context.language),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: alerts ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "ANO  De 2020 a 2023": the criterion's name in small capitals, then
/// what it asks; the Deal Score's minimum tinted green.
class const _CriterionChip(final SearchCriterion criterion)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, labelColour) = criterion.positive
        ? (
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
            scheme.onTertiaryContainer,
          )
        : (
            scheme.surfaceContainerHigh,
            scheme.onSurface,
            scheme.onSurfaceVariant,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${criterion.label.toUpperCase()}  ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: labelColour,
                ),
              ),
              TextSpan(
                text: criterion.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
