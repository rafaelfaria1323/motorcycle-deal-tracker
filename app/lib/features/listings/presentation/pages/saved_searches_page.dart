import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../../core/widgets/swipe_actions.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../cubit/saved_searches_state.dart';
import '../saved_search_summary.dart';
import '../widgets/delete_saved_search_dialog.dart';
import '../widgets/edit_saved_search_sheet.dart';
import '../../../../core/localization/localizations.dart';

class const SavedSearchesPage({super.key}) extends StatelessWidget {
  Future<void> _apply(BuildContext context, SavedSearch search) async {
    final listings = getIt<ListingsCubit>();
    // Only matters when the app was opened directly on this tab.
    if (listings.state.status == ListingsStatus.initial) {
      await listings.load();
    }
    unawaited(listings.applyFilters(search.filters));
    if (context.mounted) context.go(AppRoutes.deals);
  }

  Future<void> _create(
    BuildContext context,
    List<MotorcycleOption> motorcycles,
  ) async {
    final messageStrings = context.strings;
    final messageLanguage = context.language;

    final cubit = context.read<SavedSearchesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final draft = await showEditSavedSearchSheet(
      context,
      search: SavedSearch.draft(),
      motorcycles: motorcycles,
    );
    if (draft == null) return;
    if (savedSearchLike(cubit.state.searches, draft.filters) case final same?) {
      showMessage(messenger, alreadySavedText(same, language: messageLanguage));
      return;
    }

    final saved = await cubit.createFrom(draft);
    showMessage(
      messenger,
      saved ? messageStrings.searchSaved : messageStrings.couldNotSaveSearch,
    );
  }

  Future<void> _delete(BuildContext context, SavedSearch search) async {
    final messageStrings = context.strings;

    final cubit = context.read<SavedSearchesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await confirmDeleteSavedSearch(context, search)) return;

    final deleted = await cubit.delete(search.id);
    if (messenger.mounted) {
      showMessage(
        messenger,
        deleted
            ? messageStrings.searchDeleted
            : messageStrings.couldNotDeleteSearch,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.searches)),
      floatingActionButton: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.searches.isEmpty != current.searches.isEmpty ||
            previous.motorcycles != current.motorcycles,
        // With no searches yet the empty screen has its own button.
        builder: (context, state) =>
            state.status == SavedSearchesStatus.success &&
                state.searches.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _create(context, state.motorcycles),
                icon: const Icon(Icons.add),
                label: Text(context.strings.newSearch),
              )
            : const SizedBox.shrink(),
      ),
      body: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        builder: (context, state) {
          switch (state.status) {
            case SavedSearchesStatus.initial:
            case SavedSearchesStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case SavedSearchesStatus.failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: context.strings.couldNotLoadSearches,
                message: context.strings.checkYourConnectionAndTryAgain,
                actionLabel: context.strings.retry,
                onAction: () => context.read<SavedSearchesCubit>().load(),
              );
            case SavedSearchesStatus.success:
              if (state.searches.isEmpty) {
                return StateMessage(
                  icon: Icons.bookmark_border,
                  title: context.strings.youHaveNoSavedSearchesYet,
                  message: context.strings.createSearchAndWeWillLetYouKnow,
                  actionLabel: context.strings.newSearch,
                  onAction: () => _create(context, state.motorcycles),
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    // Room at the end so the button never covers a search.
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
                    children: [
                      PageIntro(
                        eyebrow: context.strings.savedSearches,
                        title: context.strings.yourSearches,
                        description: context.strings.searchesIntro,
                      ),
                      const SizedBox(height: 28),
                      for (final search in state.searches)
                        _SearchCard(
                          key: ValueKey(search.id),
                          search: search,
                          summary: summarizeFilters(
                            search.filters,
                            state.motorcycles,
                            language: context.language,
                          ),
                          matches: state.matchCounts[search.id] ?? 0,
                          onTap: () => _apply(context, search),
                          onEdit: () => editSavedSearch(
                            context,
                            search: search,
                            cubit: context.read<SavedSearchesCubit>(),
                          ),
                          onDelete: () => _delete(context, search),
                        ),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}

enum _SearchAction { edit, delete }

class const _SearchCard({
  required final SavedSearch search,
  required final String summary,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwipeActions(
        id: search.id,
        onEdit: onEdit,
        onDelete: onDelete,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        savedSearchName(search, language: context.language),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    PopupMenuButton<_SearchAction>(
                      tooltip: context.strings.searchOptions,
                      onSelected: (action) => switch (action) {
                        _SearchAction.edit => onEdit(),
                        _SearchAction.delete => onDelete(),
                      },
                      itemBuilder: (localizationContext) => [
                        PopupMenuItem(
                          value: _SearchAction.edit,
                          child: Text(localizationContext.strings.editSearch),
                        ),
                        PopupMenuItem(
                          value: _SearchAction.delete,
                          child: Text(localizationContext.strings.deleteSearch),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            searchNotificationText(
                              search,
                              language: context.language,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            searchMatchesText(
                              matches,
                              language: context.language,
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: scheme.primary,
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
    );
  }
}
