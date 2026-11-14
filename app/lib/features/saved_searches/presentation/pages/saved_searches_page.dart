import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../listings/domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';
import '../../../listings/presentation/cubit/listings_cubit.dart';
import '../cubit/saved_searches_cubit.dart';
import '../cubit/saved_searches_state.dart';
import '../saved_search_summary.dart';
import '../widgets/delete_saved_search_dialog.dart';
import '../widgets/edit_saved_search_sheet.dart';
import '../widgets/saved_search_card.dart';
import '../../../../core/localization/localizations.dart';

class const SavedSearchesPage({super.key}) extends StatelessWidget {
  Future<void> _apply(BuildContext context, SavedSearch search) async {
    final listings = getIt<ListingsCubit>();
    // Only matters when the app was opened directly on this tab.
    if (listings.state.status == .initial) {
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
      appBar: AppBar(
        title: Text(context.strings.searches),
        actions: [
          BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.searches.isEmpty != current.searches.isEmpty ||
                previous.motorcycles != current.motorcycles,
            // With no searches yet the empty screen has its own button.
            builder: (context, state) =>
                state.status == .success && state.searches.isNotEmpty
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: FilledButton.icon(
                      onPressed: () => _create(context, state.motorcycles),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.strings.newSearch),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        builder: (context, state) {
          switch (state.status) {
            case .initial:
            case .loading:
              return const Center(child: CircularProgressIndicator());
            case .failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: context.strings.couldNotLoadSearches,
                message: context.strings.checkYourConnectionAndTryAgain,
                actionLabel: context.strings.retry,
                onAction: () => context.read<SavedSearchesCubit>().load(),
              );
            case .success:
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      PageIntro(
                        eyebrow: context.strings.savedSearches,
                        title: context.strings.yourSearches,
                        description: context.strings.searchesIntro,
                      ),
                      const SizedBox(height: 28),
                      for (final (index, search) in state.searches.indexed)
                        SavedSearchCard(
                          key: ValueKey(search.id),
                          search: search,
                          number: index + 1,
                          criteria: searchCriteria(
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
