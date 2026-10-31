import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/favourite.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../viewing_checklist.dart';
import 'favourite_widgets.dart';
import '../../../../core/localization/localizations.dart';

/// "Para a visita" on the listing page, shown while it is a favourite: how
/// much of the viewing checklist is done; opens the list.
class const ViewingChecklistCard({required final String listingId, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      bloc: getIt<FavouritesCubit>(),
      builder: (context, state) {
        final favourite = state.favouriteOf(listingId);
        if (favourite == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(context.strings.forViewing),
            subtitle: Text(
              checklistSummaryText(
                favourite.checklist,
                language: context.language,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              constraints: const BoxConstraints(maxWidth: 560),
              builder: (_) => _ChecklistSheet(listingId: listingId),
            ),
          ),
        );
      },
    );
  }
}

class const _ChecklistSheet({required final String listingId})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) =>
          BlocBuilder<FavouritesCubit, FavouritesState>(
            bloc: getIt<FavouritesCubit>(),
            builder: (context, state) {
              final favourite = state.favouriteOf(listingId);
              // Taken out of the favourites meanwhile.
              if (favourite == null) return const SizedBox.shrink();
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    context.strings.forViewing,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.strings.checklistIntro(
                      summary: checklistSummaryText(
                        favourite.checklist,
                        language: context.language,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  for (final section in viewingChecklist(
                    language: context.language,
                  )) ...[
                    const SizedBox(height: 16),
                    Text(section.title, style: theme.textTheme.titleMedium),
                    for (final item in section.items)
                      _ChecklistTile(
                        listingId: listingId,
                        item: item,
                        entry: favourite.checklist[item.key],
                      ),
                  ],
                ],
              );
            },
          ),
    );
  }
}

class const _ChecklistTile({
  required final String listingId,
  required final ChecklistItem item,
  required final ChecklistEntry? entry,
}) extends StatelessWidget {
  Future<void> _save(
    BuildContext context, {
    required ChecklistMark? mark,
    required String? note,
  }) async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final saved = await getIt<FavouritesCubit>().saveChecklistItem(
      listingId,
      item.key,
      mark: mark,
      note: note,
    );
    if (!saved) {
      showMessage(messenger, messageStrings.couldNotSaveTryAgain);
    }
  }

  /// Tapping the selected mark again clears it.
  void _toggle(BuildContext context, ChecklistMark mark) => _save(
    context,
    mark: entry?.mark == mark ? null : mark,
    note: entry?.note,
  );

  Future<void> _editNote(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (localizationContext) => NoteDialog(
        title: item.title,
        initial: entry?.note ?? '',
        hintText: localizationContext.strings.forExampleRearTyreDOT2017,
        maxLength: FavouritesCubit.maxChecklistNoteLength,
        minLines: 2,
      ),
    );
    if (text == null || !context.mounted) return;
    await _save(context, mark: entry?.mark, note: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final note = entry?.note;
    final mark = entry?.mark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title),
      subtitle: Text(
        note ?? item.hint,
        style: note == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
      ),
      onTap: () => _editNote(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.strings.ok,
            isSelected: mark == ChecklistMark.ok,
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle, color: colors.positive),
            onPressed: () => _toggle(context, ChecklistMark.ok),
          ),
          IconButton(
            tooltip: context.strings.problem,
            isSelected: mark == ChecklistMark.issue,
            icon: const Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report, color: colors.negative),
            onPressed: () => _toggle(context, ChecklistMark.issue),
          ),
        ],
      ),
    );
  }
}
